import json
import unittest

import inventory


class DeductTest(unittest.TestCase):
    def setUp(self):
        inventory.DB.write_text('{"widget": 5}')

    def test_deduct(self):
        self.assertEqual(inventory.deduct("widget", 2), 3)

    def test_overdraw_rejected(self):
        with self.assertRaises(ValueError):
            inventory.deduct("widget", 99)


if __name__ == "__main__":
    unittest.main()
