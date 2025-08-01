/*
 * Brook PS5 Controller Board Driver
 * 
 * This driver handles Brook PS5 controller boards that advertise themselves
 * as Sony DualSense controllers but don't implement the full DualSense protocol.
 * 
 * Copyright (C) 2024
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#include <linux/device.h>
#include <linux/hid.h>
#include <linux/input.h>
#include <linux/module.h>
#include <linux/usb.h>

#define BROOK_PS5_VENDOR_ID    0x054c
#define BROOK_PS5_PRODUCT_ID   0x0ce6

#define BROOK_PS5_REPORT_SIZE  64

struct brook_ps5_device {
    struct hid_device *hdev;
    struct input_dev *input;
    struct work_struct worker;
    
    bool opened;
    
    /* Button states */
    u8 buttons[2];
    
    /* Analog stick states */
    u8 left_stick_x;
    u8 left_stick_y;
    u8 right_stick_x;
    u8 right_stick_y;
    
    /* Trigger states */
    u8 left_trigger;
    u8 right_trigger;
    
    /* D-pad state */
    u8 dpad;
};

/* Button bit definitions based on typical gamepad layout */
#define BROOK_BTN_TRIANGLE   0x80
#define BROOK_BTN_CIRCLE     0x40
#define BROOK_BTN_CROSS      0x20
#define BROOK_BTN_SQUARE     0x10
#define BROOK_BTN_L1         0x08
#define BROOK_BTN_R1         0x04
#define BROOK_BTN_L2         0x02
#define BROOK_BTN_R2         0x01

#define BROOK_BTN_SELECT     0x80
#define BROOK_BTN_START      0x40
#define BROOK_BTN_L3         0x20
#define BROOK_BTN_R3         0x10
#define BROOK_BTN_PS         0x08

/* D-pad values */
#define BROOK_DPAD_UP        0x00
#define BROOK_DPAD_UP_RIGHT  0x01
#define BROOK_DPAD_RIGHT     0x02
#define BROOK_DPAD_DOWN_RIGHT 0x03
#define BROOK_DPAD_DOWN      0x04
#define BROOK_DPAD_DOWN_LEFT 0x05
#define BROOK_DPAD_LEFT      0x06
#define BROOK_DPAD_UP_LEFT   0x07
#define BROOK_DPAD_NEUTRAL   0x08

static void brook_ps5_parse_report(struct brook_ps5_device *brook, u8 *data, int size)
{
    struct input_dev *input = brook->input;
    
    if (size < 12) {
        return;
    }
    
    /* Parse analog sticks (bytes 1-4) */
    brook->left_stick_x = data[1];
    brook->left_stick_y = data[2];
    brook->right_stick_x = data[3];
    brook->right_stick_y = data[4];
    
    /* Parse triggers (bytes 5-6) */
    brook->left_trigger = data[5];
    brook->right_trigger = data[6];
    
    /* Parse buttons (bytes 7-8) */
    brook->buttons[0] = data[7];
    brook->buttons[1] = data[8];
    
    /* Parse D-pad (lower 4 bits of byte 7) */
    brook->dpad = data[7] & 0x0f;
    
    /* Report analog sticks */
    input_report_abs(input, ABS_X, brook->left_stick_x);
    input_report_abs(input, ABS_Y, brook->left_stick_y);
    input_report_abs(input, ABS_RX, brook->right_stick_x);
    input_report_abs(input, ABS_RY, brook->right_stick_y);
    
    /* Report triggers */
    input_report_abs(input, ABS_Z, brook->left_trigger);
    input_report_abs(input, ABS_RZ, brook->right_trigger);
    
    /* Report face buttons */
    input_report_key(input, BTN_A, brook->buttons[0] & BROOK_BTN_CROSS);
    input_report_key(input, BTN_B, brook->buttons[0] & BROOK_BTN_CIRCLE);
    input_report_key(input, BTN_X, brook->buttons[0] & BROOK_BTN_SQUARE);
    input_report_key(input, BTN_Y, brook->buttons[0] & BROOK_BTN_TRIANGLE);
    
    /* Report shoulder buttons */
    input_report_key(input, BTN_TL, brook->buttons[0] & BROOK_BTN_L1);
    input_report_key(input, BTN_TR, brook->buttons[0] & BROOK_BTN_R1);
    input_report_key(input, BTN_TL2, brook->buttons[0] & BROOK_BTN_L2);
    input_report_key(input, BTN_TR2, brook->buttons[0] & BROOK_BTN_R2);
    
    /* Report control buttons */
    input_report_key(input, BTN_SELECT, brook->buttons[1] & BROOK_BTN_SELECT);
    input_report_key(input, BTN_START, brook->buttons[1] & BROOK_BTN_START);
    input_report_key(input, BTN_THUMBL, brook->buttons[1] & BROOK_BTN_L3);
    input_report_key(input, BTN_THUMBR, brook->buttons[1] & BROOK_BTN_R3);
    input_report_key(input, BTN_MODE, brook->buttons[1] & BROOK_BTN_PS);
    
    /* Report D-pad as HAT0 */
    switch (brook->dpad) {
    case BROOK_DPAD_UP:
        input_report_abs(input, ABS_HAT0X, 0);
        input_report_abs(input, ABS_HAT0Y, -1);
        break;
    case BROOK_DPAD_UP_RIGHT:
        input_report_abs(input, ABS_HAT0X, 1);
        input_report_abs(input, ABS_HAT0Y, -1);
        break;
    case BROOK_DPAD_RIGHT:
        input_report_abs(input, ABS_HAT0X, 1);
        input_report_abs(input, ABS_HAT0Y, 0);
        break;
    case BROOK_DPAD_DOWN_RIGHT:
        input_report_abs(input, ABS_HAT0X, 1);
        input_report_abs(input, ABS_HAT0Y, 1);
        break;
    case BROOK_DPAD_DOWN:
        input_report_abs(input, ABS_HAT0X, 0);
        input_report_abs(input, ABS_HAT0Y, 1);
        break;
    case BROOK_DPAD_DOWN_LEFT:
        input_report_abs(input, ABS_HAT0X, -1);
        input_report_abs(input, ABS_HAT0Y, 1);
        break;
    case BROOK_DPAD_LEFT:
        input_report_abs(input, ABS_HAT0X, -1);
        input_report_abs(input, ABS_HAT0Y, 0);
        break;
    case BROOK_DPAD_UP_LEFT:
        input_report_abs(input, ABS_HAT0X, -1);
        input_report_abs(input, ABS_HAT0Y, -1);
        break;
    default:
        input_report_abs(input, ABS_HAT0X, 0);
        input_report_abs(input, ABS_HAT0Y, 0);
        break;
    }
    
    input_sync(input);
}

static int brook_ps5_raw_event(struct hid_device *hdev, struct hid_report *report,
                               u8 *data, int size)
{
    struct brook_ps5_device *brook = hid_get_drvdata(hdev);
    
    if (!brook || !brook->input)
        return 0;
    
    brook_ps5_parse_report(brook, data, size);
    return 0;
}

static int brook_ps5_input_open(struct input_dev *dev)
{
    struct brook_ps5_device *brook = input_get_drvdata(dev);
    int ret;
    
    ret = hid_hw_open(brook->hdev);
    if (ret)
        return ret;
    
    brook->opened = true;
    return 0;
}

static void brook_ps5_input_close(struct input_dev *dev)
{
    struct brook_ps5_device *brook = input_get_drvdata(dev);
    
    brook->opened = false;
    hid_hw_close(brook->hdev);
}

static int brook_ps5_setup_input(struct brook_ps5_device *brook)
{
    struct hid_device *hdev = brook->hdev;
    struct input_dev *input;
    int ret;
    
    input = devm_input_allocate_device(&hdev->dev);
    if (!input)
        return -ENOMEM;
    
    brook->input = input;
    input_set_drvdata(input, brook);
    
    input->name = "Brook PS5 Controller";
    input->phys = hdev->phys;
    input->uniq = hdev->uniq;
    input->id.bustype = hdev->bus;
    input->id.vendor = hdev->vendor;
    input->id.product = hdev->product;
    input->id.version = hdev->version;
    input->dev.parent = &hdev->dev;
    
    input->open = brook_ps5_input_open;
    input->close = brook_ps5_input_close;
    
    /* Set up button capabilities */
    __set_bit(EV_KEY, input->evbit);
    __set_bit(BTN_A, input->keybit);
    __set_bit(BTN_B, input->keybit);
    __set_bit(BTN_X, input->keybit);
    __set_bit(BTN_Y, input->keybit);
    __set_bit(BTN_TL, input->keybit);
    __set_bit(BTN_TR, input->keybit);
    __set_bit(BTN_TL2, input->keybit);
    __set_bit(BTN_TR2, input->keybit);
    __set_bit(BTN_SELECT, input->keybit);
    __set_bit(BTN_START, input->keybit);
    __set_bit(BTN_THUMBL, input->keybit);
    __set_bit(BTN_THUMBR, input->keybit);
    __set_bit(BTN_MODE, input->keybit);
    
    /* Set up absolute axis capabilities */
    __set_bit(EV_ABS, input->evbit);
    
    /* Analog sticks */
    input_set_abs_params(input, ABS_X, 0, 255, 0, 0);
    input_set_abs_params(input, ABS_Y, 0, 255, 0, 0);
    input_set_abs_params(input, ABS_RX, 0, 255, 0, 0);
    input_set_abs_params(input, ABS_RY, 0, 255, 0, 0);
    
    /* Triggers */
    input_set_abs_params(input, ABS_Z, 0, 255, 0, 0);
    input_set_abs_params(input, ABS_RZ, 0, 255, 0, 0);
    
    /* D-pad as HAT */
    input_set_abs_params(input, ABS_HAT0X, -1, 1, 0, 0);
    input_set_abs_params(input, ABS_HAT0Y, -1, 1, 0, 0);
    
    ret = input_register_device(input);
    if (ret) {
        hid_err(hdev, "Failed to register input device: %d\n", ret);
        return ret;
    }
    
    return 0;
}

static int brook_ps5_probe(struct hid_device *hdev, const struct hid_device_id *id)
{
    struct brook_ps5_device *brook;
    int ret;
    
    hid_info(hdev, "Brook PS5 Controller detected\n");
    
    brook = devm_kzalloc(&hdev->dev, sizeof(*brook), GFP_KERNEL);
    if (!brook)
        return -ENOMEM;
    
    brook->hdev = hdev;
    hid_set_drvdata(hdev, brook);
    
    ret = hid_parse(hdev);
    if (ret) {
        hid_err(hdev, "Failed to parse HID descriptor: %d\n", ret);
        return ret;
    }
    
    ret = hid_hw_start(hdev, HID_CONNECT_HIDRAW);
    if (ret) {
        hid_err(hdev, "Failed to start HID device: %d\n", ret);
        return ret;
    }
    
    ret = brook_ps5_setup_input(brook);
    if (ret) {
        hid_err(hdev, "Failed to setup input device: %d\n", ret);
        hid_hw_stop(hdev);
        return ret;
    }
    
    hid_info(hdev, "Brook PS5 Controller initialized successfully\n");
    return 0;
}

static void brook_ps5_remove(struct hid_device *hdev)
{
    struct brook_ps5_device *brook = hid_get_drvdata(hdev);
    
    if (brook && brook->opened)
        hid_hw_close(hdev);
    
    hid_hw_stop(hdev);
    hid_info(hdev, "Brook PS5 Controller removed\n");
}

static const struct hid_device_id brook_ps5_devices[] = {
    { HID_USB_DEVICE(BROOK_PS5_VENDOR_ID, BROOK_PS5_PRODUCT_ID) },
    { }
};
MODULE_DEVICE_TABLE(hid, brook_ps5_devices);

static struct hid_driver brook_ps5_driver = {
    .name = "brook-ps5",
    .id_table = brook_ps5_devices,
    .probe = brook_ps5_probe,
    .remove = brook_ps5_remove,
    .raw_event = brook_ps5_raw_event,
};

static int __init brook_ps5_init(void)
{
    return hid_register_driver(&brook_ps5_driver);
}

static void __exit brook_ps5_exit(void)
{
    hid_unregister_driver(&brook_ps5_driver);
}

module_init(brook_ps5_init);
module_exit(brook_ps5_exit);

MODULE_AUTHOR("Brook PS5 Driver");
MODULE_DESCRIPTION("Driver for Brook PS5 Controller Boards");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("1.0");