# Import necessary modules
import os
import uuid
from locust import HttpUser, task, between
from dotenv import load_dotenv

# Load environment variables, including from a .env file
load_dotenv()

class ApiUser(HttpUser):
    wait_time = between(1, 3)
    host = "http://PUBLIC_IP"
    timeout_duration = 90
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.ENABLE_LOGGING = os.getenv('ENABLE_LOGGING', 'True') == 'True'
        
    ## The main task that runs the sequence of operations based on the HTTP Request File
    @task
    def run_scenario(self):
        """Execute all operations in sequence as defined in the HTTP Request File"""
        self.get_homepage()
        
    ## The functions for each operation in the HTTP Request File
    def get_homepage(self):
        """Get the homepage"""
        url = "/"
        
        if self.ENABLE_LOGGING:
            print(f"[REQUEST] Get the homepage - URL: {url}")
        
        with self.client.get(
            url=url,
            name="Get the homepage",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code in [200]:
                response.success()
                if self.ENABLE_LOGGING:
                    print(f"[SUCCESS] Get the homepage - Status: {response.status_code}")
            else:
                response.failure(f"Get the homepage failed with status {response.status_code}")
                if self.ENABLE_LOGGING:
                    print(f"[ERROR] Get the homepage failed")
                    print(f"  URL: {url}")
                    print(f"  Status Code: {response.status_code}")
                    print(f"  Response: {response.text}")

    ## The on_start and on_stop functions
    def on_start(self):
        """Called when a simulated user starts"""
        if self.ENABLE_LOGGING:
            print("[INFO] Starting new user session")

    def on_stop(self):
        """Called when a simulated user stops - clean up any resources created during the test"""
        if self.ENABLE_LOGGING:
            print("[INFO] Stopping user session")
        # No resources were created that need cleanup in this test scenario

# Run the test locally:
# locust -f locustfile.py -u 200 -r 10 --run-time 120s

# Run the test at scale, distributed across multiple regions:
# In Visual Studio Code, use the "Load Testing: Run load test" command.