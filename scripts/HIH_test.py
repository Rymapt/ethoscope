#! /usr/bin/env python

"""
Tests for the HIH6130 class which talks to the HIH6130 temperature and humidity sensor.
"""

__author__    = "Paolo Baesso, Mark Grimes"
__copyright__ = "Copyright 2017, Rymapt Ltd"
__license__   = "MIT"
# MIT licence is available at https://opensource.org/licenses/MIT

import unittest
import easyi2c
from HIH6130 import HIH6130

class TestTargetROIBuilder(unittest.TestCase):
    def test_constructWitheasyi2c(self):
        DEVICE_ADDRESS= 0x27 #For temperature sensor
        easybus= easyi2c.IIC(DEVICE_ADDRESS, 1)
        myHIH = HIH6130(easybus)
        self.performTests(myHIH)

    def test_constructAutomatically(self):
        myHIH = HIH6130()
        self.performTests(myHIH)

    def performTests(self, device):
        data = device.getData()
        self.assertEqual(len(data), 3)
        # Test the status bits
        self.assertEqual(data[0], 0)
        # Test the relative humidity.
        self.assertGreaterEqual(data[1], 0)
        self.assertLessEqual(data[1], 100)
        # Test the temperature. These temperatures are taken from the documented
        # operating temperature, so if you're testing when the temperature is outside
        # this range the chip probably won't work anyway.
        self.assertGreaterEqual(data[1], -25)
        self.assertLessEqual(data[1], 85)

if __name__ == "__main__":
    unittest.main()
