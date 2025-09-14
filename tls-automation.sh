#!/bin/bash

# AKS Let's Encrypt Certificate Setup Script

set -e

echo "=== Azure Let's Encrypt Certificate Setup ==="
echo "Create resource group: 'wisecow-rg' in East US 2"
read -p "Press Enter to continue once done..."

# Set environment variables
export AZURE_DEFAULTS_GROUP=<rg-name>
export AZURE_DEFAULTS_LOCATION=eastus2
export DOMAIN_NAME=<domain>
export CLUSTER=<cluster-name>
export EMAIL_ADDRESS=<email>
export USER_ASSIGNED_IDENTITY_NAME=<identity-name>

echo "=== Step 1: Creating DNS Zone ==="
az network dns zone create --name $DOMAIN_NAME
az network dns zone show --name $DOMAIN_NAME --output yaml

echo "=== Step 2: Creating AKS Cluster ==="
az aks create \
    --name ${CLUSTER} \
    --node-count 1 \
    --node-vm-size "Standard_B2s" \
    --load-balancer-sku basic \
    --generate-ssh-keys \
    --enable-oidc-issuer \
    --enable-workload-identity

echo "=== Step 3: Getting AKS Credentials ==="
az aks get-credentials --admin --name "$CLUSTER"
kubectl get nodes -o wide

echo "=== Step 4: Installing cert-manager with Workload Identity ==="
helm repo add jetstack https://charts.jetstack.io --force-update

# Create values.yaml for workload identity
cat > values.yaml << EOF
podLabels:
  azure.workload.identity/use: "true"
serviceAccount:
  labels:
    azure.workload.identity/use: "true"
EOF

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true \
  --values values.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

echo "=== Step 5: Creating Managed Identity and Role Assignment ==="
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group ${AZURE_DEFAULTS_GROUP}

export USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az identity show --resource-group ${AZURE_DEFAULTS_GROUP} --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' -o tsv)

# Assign DNS Zone Contributor role
az role assignment create \
    --role "DNS Zone Contributor" \
    --assignee "$USER_ASSIGNED_IDENTITY_CLIENT_ID" \
    --scope $(az network dns zone show \
        --name "$DOMAIN_NAME" \
        --resource-group "$AZURE_DEFAULTS_GROUP" \
        --query id -o tsv)

echo "=== Step 6: Setting up Federated Identity Credential ==="
export SERVICE_ACCOUNT_NAME=cert-manager
export SERVICE_ACCOUNT_NAMESPACE=cert-manager
export SERVICE_ACCOUNT_ISSUER=$(az aks show --resource-group $AZURE_DEFAULTS_GROUP --name $CLUSTER --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
    --name "cert-manager" \
    --resource-group ${AZURE_DEFAULTS_GROUP} \
    --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --issuer "${SERVICE_ACCOUNT_ISSUER}" \
    --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"

echo "=== Step 7: Getting Azure Subscription ID ==="
export AZURE_SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

echo "=== Step 8: Creating Let's Encrypt Production ClusterIssuer ==="
cat > clusterissuer-lets-encrypt-production.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL_ADDRESS}
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        azureDNS:
          resourceGroupName: ${AZURE_DEFAULTS_GROUP}
          subscriptionID: ${AZURE_SUBSCRIPTION_ID}
          hostedZoneName: ${DOMAIN_NAME}
          environment: AzurePublicCloud
          managedIdentity:
            clientID: ${USER_ASSIGNED_IDENTITY_CLIENT_ID}
EOF

kubectl apply -f clusterissuer-lets-encrypt-production.yaml

echo "=== Step 9: Creating Let's Encrypt Certificate (Direct Production) ==="
cat > certificate.yaml << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-tls
  privateKey:
    rotationPolicy: Always
  commonName: www.${DOMAIN_NAME}
  dnsNames:
    - www.${DOMAIN_NAME}
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
EOF

kubectl apply -f certificate.yaml

echo "=== Step 10: Creating Application Deployment ==="
cat > deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app-tls:1.0
        imagePullPolicy: Always
        ports:
        - containerPort: 8443
        volumeMounts:
          - name: tls
            mountPath: /etc/tls
            readOnly: true
        env:
          - name: TLS_CERT
            value: /etc/tls/tls.crt
          - name: TLS_KEY
            value: /etc/tls/tls.key
      volumes:
      - name: tls
        secret:
          secretName: www-tls
EOF

kubectl apply -f deployment.yaml

echo "=== Step 11: Creating LoadBalancer Service ==="
export AZURE_LOADBALANCER_DNS_LABEL_NAME=lb-$(uuidgen | tr '[:upper:]' '[:lower:]')

cat > service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
    name: helloweb
    annotations:
        service.beta.kubernetes.io/azure-dns-label-name: ${AZURE_LOADBALANCER_DNS_LABEL_NAME}
spec:
    ports:
    - port: 443
      protocol: TCP
      targetPort: 8443
    selector:
        app: hello
        tier: web
    type: LoadBalancer
EOF

kubectl apply -f service.yaml

echo "=== Step 12: Waiting for LoadBalancer External IP ==="
echo "Waiting for external IP assignment..."
while true; do
    EXTERNAL_IP=$(kubectl get service helloweb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo "External IP assigned: $EXTERNAL_IP"
        break
    fi
    echo "Still waiting for external IP..."
    sleep 10
done

echo "=== Step 13: Creating DNS CNAME Record ==="
az network dns record-set cname set-record \
    --zone-name $DOMAIN_NAME \
    --cname $AZURE_LOADBALANCER_DNS_LABEL_NAME.$AZURE_DEFAULTS_LOCATION.cloudapp.azure.com \
    --record-set-name www

echo "=== Step 14: Waiting for Certificate Issuance ==="
echo "Waiting for Let's Encrypt certificate to be issued..."
kubectl wait --for=condition=Ready certificate/www --timeout=600s

echo "=== Step 15: Verification ==="
echo "Checking certificate status..."
kubectl describe certificate www
kubectl get secret www-tls

echo "=== Setup Complete! ==="
echo "Your domain: https://www.$DOMAIN_NAME"
echo "LoadBalancer DNS: https://$AZURE_LOADBALANCER_DNS_LABEL_NAME.$AZURE_DEFAULTS_LOCATION.cloudapp.azure.com"
echo ""
echo "Wait a few minutes for DNS propagation, then test with:"
echo "curl -v https://www.$DOMAIN_NAME"
echo ""
echo "If you encounter issues, check certificate status with:"
echo "kubectl describe certificate www"
echo "kubectl describe certificaterequest"
echo "kubectl logs -n cert-manager deployment/cert-manager"