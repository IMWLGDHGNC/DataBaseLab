"""Capture sanitized role pages on the server; credentials never leave it."""

import os
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


config_path = Path(os.environ["APP_CONFIG_FILE"])
credentials = {}
for line in config_path.with_name("demo-credentials.txt").read_text(encoding="utf-8").splitlines():
    if ": " in line:
        name, password = line.split(": ", 1)
        credentials[name] = password
base = os.environ.get("APP_BASE_URL", "http://127.0.0.1:8767")
output = Path(os.environ.get("SCREENSHOT_DIR", "output/week7/screenshots"))
output.mkdir(parents=True, exist_ok=True)
options = Options()
options.add_argument("-headless")
if os.environ.get("FIREFOX_BINARY"):
    options.binary_location = os.environ["FIREFOX_BINARY"]
driver = webdriver.Firefox(options=options)
driver.set_window_size(1380, 1000)
wait = WebDriverWait(driver, 15)


def screenshot(name):
    height = driver.execute_script("return document.documentElement.scrollHeight")
    driver.set_window_size(1380, min(max(height + 80, 1000), 3600))
    driver.save_screenshot(str(output / name))
    driver.set_window_size(1380, 1000)
    print("SCREENSHOT", name)


try:
    driver.get(base)
    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "#products-body tr")))
    screenshot("01-public-products.png")
    for role, filename in (
        ("customer", "02-customer-orders.png"),
        ("staff", "03-staff-inventory.png"),
        ("manager", "04-manager-products.png"),
    ):
        driver.find_element(By.CSS_SELECTOR, "#login-form input[name=username]").send_keys(role + "_demo")
        driver.find_element(By.CSS_SELECTOR, "#login-form input[name=password]").send_keys(credentials[role + "_demo"])
        driver.find_element(By.CSS_SELECTOR, "#login-form button[type=submit]").click()
        wait.until(lambda browser: role + "_demo" in browser.find_element(By.ID, "account").text)
        wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "#orders-body tr")))
        screenshot(filename)
        if role == "customer":
            driver.find_element(By.ID, "cart-qty").clear()
            driver.find_element(By.ID, "cart-qty").send_keys("0")
            driver.find_element(By.ID, "cart-add").click()
            wait.until(lambda browser: "正整数" in browser.find_element(By.ID, "notice").text)
            screenshot("05-friendly-input-error.png")
        driver.find_element(By.ID, "logout").click()
        wait.until(EC.visibility_of_element_located((By.ID, "login-form")))
finally:
    driver.quit()
