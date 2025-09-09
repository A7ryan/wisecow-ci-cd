# Reference
# https://stackoverflow.com/questions/276052/how-can-i-get-current-cpu-and-ram-usage-in-python
# https://pypi.org/project/psutil/
# https://psutil.readthedocs.io/en/latest/#psutil.cpu_percent
# https://blogs.glowscotland.org.uk/sh/ahscomputingpython/higher/writing-data-to-a-text-file/

import time
import psutil
import datetime

def check_cpu_log():
    # CPU consumed - https://psutil.readthedocs.io/en/latest/#psutil.cpu_percent
    total_cpu_cores = psutil.cpu_count(logical=True)
    free_cpu_cores = psutil.cpu_count(logical=False)
    percent_cpu_used = psutil.cpu_percent(interval=1, percpu=False)
    used_cpu_cores = total_cpu_cores - free_cpu_cores

    store_cpu_logs = [percent_cpu_used]

    print(f"""
    Total CPU Cores: {total_cpu_cores} \t
    Used CPU Cores: {used_cpu_cores} \t
    Free CPU Cores: {free_cpu_cores} \t
    Percent Used: {percent_cpu_used}% \t
        """)

    return store_cpu_logs
    


def check_memory_logs():
    # Memory consumed - https://psutil.readthedocs.io/en/latest/#psutil.virtual_memory
    memory_logs = psutil.virtual_memory()
    
    total_memory_in_gb = memory_logs[0] / (1024 ** 3)
    free_memory_in_gb = memory_logs[1] / (1024 ** 3)
    percent_memory_used = memory_logs[2]
    used_memory_in_gb = memory_logs[3] / (1024 ** 3)

    store_memory_logs = [percent_memory_used]

    print(f"""
    Total Memory: {total_memory_in_gb} GB \t
    Used Memory: {used_memory_in_gb} GB \t
    Free Memory: {free_memory_in_gb} GB \t
    Percent Used: {percent_memory_used}% \t
        """)

    return store_memory_logs



def check_disk_logs():
    # Disk consumed - https://psutil.readthedocs.io/en/latest/#psutil.disk_usage
    disk_logs = psutil.disk_usage('/')

    total_disk_in_gb = disk_logs[0] / (1024 ** 3)
    used_disk_in_gb = disk_logs[1] / (1024 ** 3)
    free_disk_in_gb = disk_logs[2] / (1024 ** 3)
    percent_disk_used = disk_logs[3]

    store_disk_logs = [percent_disk_used]

    print(f""" 
    Total Disk: {total_disk_in_gb} GB \t
    Used Disk: {used_disk_in_gb} GB \t
    Free Disk: {free_disk_in_gb} GB \t
    Percent Used: {percent_disk_used}% \t
        """)
    
    return store_disk_logs


def check_pid_logs():
    # https://psutil.readthedocs.io/en/latest/#psutil.pids
    for proc in psutil.process_iter():
        pass

    time.sleep(1)
    
    top_memory_pid = []
    for proc in psutil.process_iter(['pid', 'name', 'username', 'memory_percent']):
        if proc.info['memory_percent'] > 0.0:
            top_memory_pid.append(proc.info)

    most_pid_memory_usage = sorted(top_memory_pid, key=lambda x: x['memory_percent'], reverse=True)[:5]
    print(most_pid_memory_usage)
    
    # psutil.process_iter.cache_clear()


def write_logs():
    try:
        OUT_FILE= 'system-logs.txt'
        cpu_data = check_cpu_log()
        memory_data = check_memory_logs()
        disk_data = check_disk_logs()
        final_log = []
        final_log.append(f"Timestamp: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        if cpu_data[0] > 80:
            final_log.append(f"CPU Usage Alert: {cpu_data[0]}%")
        if memory_data[0] > 80:
            final_log.append(f"Memory Usage Alert: {memory_data[0]}%")
        if disk_data[0] > 80:
            final_log.append(f"Disk Usage Alert: {disk_data[0]}%")    
        
        f = open(OUT_FILE, 'a')
        f.write(f"{final_log}\n")
        f.close()
        print("log written successfully..")
    except Exception as e:
        print("Cannot Write Logs! Error: ", e)
    finally:
        print("Task Completed Success..")
        

if __name__ == "__main__":
    write_logs()
    # if want to run continously, uncomment below code
    # while True:
    #     write_logs()
    #     time.sleep(300)  # updates every 5 minutes
