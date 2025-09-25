import time
import os
import requests
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# sudo dnf install python3-selenium chromedriver chromium

# Setup headless Chrome
options = Options()
options.add_argument("--headless")
options.add_argument("--disable-gpu")
options.add_argument("--no-sandbox")
options.add_argument("--window-size=1920,1080")

# Path to your chromedriver (adjust if needed)
service = Service("/usr/bin/chromedriver")
driver = webdriver.Chrome(service=service, options=options)

try:
    # Step 1: Load TechPowerUp download page
    driver.get("https://www.techpowerup.com/download/vmware-workstation-pro/")

    # Step 2: Find and submit the Linux version form (id=2914)
    linux_form = WebDriverWait(driver, 15).until(
        EC.presence_of_element_located((By.XPATH, "//form[input[@name='id' and @value='2914']]"))
    )
    driver.execute_script("arguments[0].submit();", linux_form)
    print("✅ Submitted Linux version form")

    # Step 3: Wait for mirror selection form
    mirror_form = WebDriverWait(driver, 15).until(
        EC.presence_of_element_located((By.XPATH, "//form[@method='POST']"))
    )
    mirror_url = mirror_form.get_attribute("action")
    hidden_id = mirror_form.find_element(By.NAME, "id").get_attribute("value")
    print("✅ Mirror form action URL:", mirror_url)
    print("✅ Hidden ID value:", hidden_id)

finally:
    driver.quit()

# Step 4: Submit POST request to mirror with correct data
print("⏳ Downloading Linux .bundle file from TechPowerUp NL mirror...")
response = requests.post(mirror_url, data={"id": hidden_id, "server_id": "27"})

# Step 5: Save to ~/.vmware
vmware_dir = os.path.join(os.path.expanduser("~"), ".vmware")
os.makedirs(vmware_dir, exist_ok=True)
bundle_path = os.path.join(vmware_dir, "vmware-workstation-linux.bundle")
with open(bundle_path, "wb") as f:
    f.write(response.content)

print(f"✅ Download complete: {bundle_path}")
