# wisecow-ci-cd

### Folder Structure

### wisecow-ci-cd/
    |
    |-- README.md
    |-- LICENSE
    │
    |-- .github/
    │
    |-- problem-statement-1/
    │   |-- Dockerfile
    │   |-- wisecow.sh
    │   |-- references.txt
    │   |-- k8s/
    │       |-- deployment.yaml
    │       |-- service.yaml
    │
    |-- problem-statement-2/
    |-- system-health-monitoring.py
    |-- application-health-checker.py
    |-- system-logs.txt


### 

### TLS: https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/

### i. Purchased a Free Domain: 
        -- https://freedomain.one

        -- https://mydomain/

### ii. Tried the full tutorial but could only setup self-signed certificate
    -- Tried of Step 2 using Let's Encrypt CA but it did not got updated.
    -- FreeDomain for free users do not support:
            Modification of Name Servers

### iii. Conclusion
    Single VM TLS done
    
    Self-Signed Certificate over K8s Completed

    Could not complete K8s -> TLS -> Let's Encrypt.
    However understood the concept.

    In case, I could learn from someone's guidance and implement it soon..


### Future Work - Secret DO-NOT-README FILE
    Once I implement the K8s TLS,
    I have created an automated script which
    anyone can use for their K8s Pod TLS Automation 
    [domain name TLS K8s-Pod Automation]
    to save time + effort!
