import time
import easyi2c

from HIH6130 import HIH6130

DEVICE_ADDRESS= 0x27 #For temperature sensor
easybus= easyi2c.IIC(DEVICE_ADDRESS, 1)
myHIH= HIH6130(easybus)

print myHIH.getData()
