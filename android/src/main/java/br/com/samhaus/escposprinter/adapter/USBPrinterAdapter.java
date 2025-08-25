package br.com.samhaus.escposprinter.adapter;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.util.Base64;
import android.util.Log;
import android.widget.Toast;


import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class USBPrinterAdapter {
    private static USBPrinterAdapter mInstance;


    private String LOG_TAG = "ESC POS Printer";
    private Context mContext;
    private UsbManager mUSBManager;
    private PendingIntent mPermissionIndent;
    private UsbDevice mUsbDevice ;
    private UsbDeviceConnection mUsbDeviceConnection;
    private UsbInterface mUsbInterface;
    private UsbEndpoint mEndPoint;
    //private static final String ACTION_USB_PERMISSION = "com.pinmi.react.USBPrinter.USB_PERMISSION";
    private static final String ACTION_USB_PERMISSION = "br.com.samhaus.escposprinter.USB_PERMISSION";



    private USBPrinterAdapter(){}

    public static USBPrinterAdapter getInstance() {
        if(mInstance == null) {
            mInstance = new USBPrinterAdapter();
        }
        return mInstance;
    }

    private final BroadcastReceiver mUsbDeviceReceiver  = new BroadcastReceiver(){
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            Log.d(LOG_TAG, "BroadcastReceiver onReceive: " + action);

            if(ACTION_USB_PERMISSION.equals(action)){
                synchronized (this) {
                    UsbDevice usbDevice;
                    // Fix for Android API 33+ (TIRAMISU)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        usbDevice = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice.class);
                    } else {
                        usbDevice = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    }

                    Log.d(LOG_TAG, "USB Device from intent: " + (usbDevice != null ? usbDevice.getDeviceName() : "null"));
                    Log.d(LOG_TAG, "Permission granted: " + intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false));

                    boolean permissionGranted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false);

                    if(permissionGranted && usbDevice != null){
                        Log.i(LOG_TAG, "Success to grant permission for device "+usbDevice.getDeviceId()+", vendor_id: "+ usbDevice.getVendorId()+ " product_id: " + usbDevice.getProductId());
                        mUsbDevice = usbDevice;
                        Toast.makeText(context, "USB device permission granted", Toast.LENGTH_SHORT).show();
                    } else {
                        if (usbDevice != null) {
                            Log.w(LOG_TAG, "User refused USB permission for device: " + usbDevice.getDeviceName());
                            Toast.makeText(context, "User refused to give USB device permissions for " + usbDevice.getDeviceName(), Toast.LENGTH_LONG).show();
                        } else {
                            Log.e(LOG_TAG, "USB device is null in permission response");
                            Toast.makeText(context, "USB device permission failed - device is null", Toast.LENGTH_LONG).show();
                        }
                        mUsbDevice = null;
                    }
                }
            } else if(UsbManager.ACTION_USB_DEVICE_DETACHED.equals(action)){
                UsbDevice detachedDevice;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    detachedDevice = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice.class);
                } else {
                    detachedDevice = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                }

                if(mUsbDevice != null && detachedDevice != null &&
                        mUsbDevice.getDeviceId() == detachedDevice.getDeviceId()){
                    Log.i(LOG_TAG, "Current USB device has been detached");
                    Toast.makeText(context, "USB device has been disconnected", Toast.LENGTH_LONG).show();
                    closeConnectionIfExists();
                    mUsbDevice = null;
                }
            }
        }
    };

    public void init(Context reactContext) {
        this.mContext = reactContext;
        this.mUSBManager = (UsbManager) this.mContext.getSystemService(Context.USB_SERVICE);

        // Create intent with explicit action
        Intent permissionIntent = new Intent(ACTION_USB_PERMISSION);
        permissionIntent.setPackage(mContext.getPackageName());

        // Fix for PendingIntent flags based on API level
        int flags;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = PendingIntent.FLAG_MUTABLE;
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = PendingIntent.FLAG_IMMUTABLE;
        } else {
            flags = 0;
        }

        this.mPermissionIndent = PendingIntent.getBroadcast(mContext, 0, permissionIntent, flags);

        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED);

        // Fix for registerReceiver based on API level
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            mContext.registerReceiver(mUsbDeviceReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            mContext.registerReceiver(mUsbDeviceReceiver, filter);
        }

        Log.v(LOG_TAG, "ESC POS Printer initialized with package: " + mContext.getPackageName());
    }


    public void closeConnectionIfExists() {
        if(mUsbDeviceConnection != null) {
            mUsbDeviceConnection.releaseInterface(mUsbInterface);
            mUsbDeviceConnection.close();
            mUsbInterface = null;
            mEndPoint = null;
            mUsbDeviceConnection = null;
        }
    }

    public List<UsbDevice> getDeviceList() {
        if (mUSBManager == null) {
            Toast.makeText(mContext, "USB Manager is not initialized while get device list", Toast.LENGTH_LONG).show();
            return Collections.emptyList();
        }
        return new ArrayList<UsbDevice>(mUSBManager.getDeviceList().values());
    }

    public boolean selectDevice(Integer vendorId, Integer productId) {
        Log.d(LOG_TAG, "selectDevice called with vendorId: " + vendorId + ", productId: " + productId);

        if(mUsbDevice == null || mUsbDevice.getVendorId() != vendorId || mUsbDevice.getProductId() != productId) {
            closeConnectionIfExists();
            List<UsbDevice> usbDevices = getDeviceList();
            Log.d(LOG_TAG, "Found " + usbDevices.size() + " USB devices");

            for(UsbDevice usbDevice: usbDevices){
                Log.d(LOG_TAG, "Checking device: vendor=" + usbDevice.getVendorId() + ", product=" + usbDevice.getProductId());
                if((usbDevice.getVendorId() == vendorId) && (usbDevice.getProductId() == productId)){
                    Log.v(LOG_TAG, "Found matching device: vendor_id: " + usbDevice.getVendorId() + ", product_id: " + usbDevice.getProductId());

                    // Check if we already have permission
                    if(mUSBManager.hasPermission(usbDevice)) {
                        Log.i(LOG_TAG, "Already have permission for device");
                        mUsbDevice = usbDevice;
                        return true;
                    } else {
                        Log.i(LOG_TAG, "Requesting permission for device");
                        closeConnectionIfExists();
                        mUSBManager.requestPermission(usbDevice, mPermissionIndent);
                        return true;
                    }
                }
            }
            Log.w(LOG_TAG, "No matching USB device found");
            return false;
        }
        Log.d(LOG_TAG, "Device already selected and matches criteria");
        return true;
    }

    public boolean openConnection() {
        if(mUsbDevice == null){
            Log.e(LOG_TAG, "USB Deivce is not initialized");
            return false;
        }
        if(mUSBManager == null) {
            Log.e(LOG_TAG, "USB Manager is not initialized");
            return false;
        }

        if(mUsbDeviceConnection != null) {
            Log.i(LOG_TAG, "USB Connection already connected");
            return true;
        }

        UsbInterface usbInterface = mUsbDevice.getInterface(0);
        for(int i = 0; i < usbInterface.getEndpointCount(); i++){
            final UsbEndpoint ep = usbInterface.getEndpoint(i);
            if(ep.getType() == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if(ep.getDirection() == UsbConstants.USB_DIR_OUT) {
                    UsbDeviceConnection usbDeviceConnection = mUSBManager.openDevice(mUsbDevice);
                    if(usbDeviceConnection == null) {
                        Log.e(LOG_TAG, "failed to open USB Connection");
                        return false;
                    }
                    Toast.makeText(mContext, "Device connected", Toast.LENGTH_SHORT).show();
                    if (usbDeviceConnection.claimInterface(usbInterface, true)){
                        mEndPoint = ep;
                        mUsbInterface = usbInterface;
                        mUsbDeviceConnection = usbDeviceConnection;
                        return true;
                    }else{
                        usbDeviceConnection.close();
                        Log.e(LOG_TAG, "failed to claim usb connection");
                        return false;
                    }
                }
            }
        }
        return true;
    }

    public boolean printText(String text){
        final String printData = text;
        Log.v(LOG_TAG, "start to print text");
        boolean isConnected = openConnection();
        if(isConnected) {
            Log.v(LOG_TAG, "Connected to device");
            new Thread(new Runnable() {
                @Override
                public void run() {
                    byte [] bytes = printData.getBytes(Charset.forName("UTF-8"));
                    int b = mUsbDeviceConnection.bulkTransfer(mEndPoint, bytes, bytes.length, 100000);
                    Log.i(LOG_TAG, "Return Status: b-->"+b);
                }
            }).start();
            return true;
        }else{
            Log.v(LOG_TAG, "failed to connected to device");
            return false;
        }
    }

    public boolean printRawData(String data) {
        final String rawData = data;
        Log.v(LOG_TAG, "start to print raw data " + data);
        boolean isConnected = openConnection();
        if(isConnected) {
            Log.v(LOG_TAG, "Connected to device");
            new Thread(new Runnable() {
                @Override
                public void run() {
                    byte [] bytes = Base64.decode(rawData, Base64.DEFAULT);
                    int b = mUsbDeviceConnection.bulkTransfer(mEndPoint, bytes, bytes.length, 100000);
                    Log.i(LOG_TAG, "Return Status: "+b);
                }
            }).start();
            return true;
        }else{
            Log.v(LOG_TAG, "failed to connected to device");
            return false;
        }
    }

    public boolean write(final byte [] bytes) {
        Log.v(LOG_TAG, "start to print raw data " + bytes);
        boolean isConnected = openConnection();
        if(isConnected) {
            Log.v(LOG_TAG, "Connected to device");
            new Thread(new Runnable() {
                @Override
                public void run() {
//                    byte [] bytes = Base64.decode(rawData, Base64.DEFAULT);
                    int b = mUsbDeviceConnection.bulkTransfer(mEndPoint, bytes, bytes.length, 100000);
                    Log.i(LOG_TAG, "Return Status: "+b);
                }
            }).start();
            return true;
        }else{
            Log.v(LOG_TAG, "failed to connected to device");
            return false;
        }
    }

}