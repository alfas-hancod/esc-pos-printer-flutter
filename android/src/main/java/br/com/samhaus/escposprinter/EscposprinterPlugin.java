package br.com.samhaus.escposprinter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import android.app.Activity;
import android.hardware.usb.UsbDevice;
import br.com.samhaus.escposprinter.adapter.USBPrinterAdapter;
import java.util.List;
import java.util.ArrayList;
import java.util.HashMap;

/** EscposprinterPlugin */
public class EscposprinterPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private USBPrinterAdapter adapter;
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "escposprinter");
    channel.setMethodCallHandler(this);
    adapter = USBPrinterAdapter.getInstance();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getUSBDeviceList")) {
      getUSBDeviceList(result);
    } else if (call.method.equals("connectPrinter")) {
      Integer vendor = call.argument("vendor");
      Integer product = call.argument("product");
      connectPrinter(vendor, product, result);
    } else if (call.method.equals("closeConn")) {
      closeConn(result);
    } else if (call.method.equals("printText")) {
      String text = call.argument("text");
      printText(text, result);
    } else if (call.method.equals("printRawData")) {
      String raw = call.argument("raw");
      printRawData(raw, result);
    } else if (call.method.equals("write")) {
        byte [] data = call.argument("data");
        write(data, result);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    adapter.init(activity);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  public void getUSBDeviceList(Result result) {
        List<UsbDevice> usbDevices = adapter.getDeviceList();
        ArrayList<HashMap> list = new ArrayList<HashMap>();
        for (UsbDevice usbDevice : usbDevices) {
            HashMap<String, String> deviceMap = new HashMap();
            deviceMap.put("name", usbDevice.getDeviceName());
            deviceMap.put("manufacturer", usbDevice.getManufacturerName());
            deviceMap.put("product", usbDevice.getProductName());
            deviceMap.put("deviceid", Integer.toString(usbDevice.getDeviceId()));
            deviceMap.put("vendorid", Integer.toString(usbDevice.getVendorId()));
            deviceMap.put("productid", Integer.toString(usbDevice.getProductId()));
            list.add(deviceMap);
        }
        result.success(list);
    }


    public void connectPrinter(Integer vendorId, Integer productId, Result result) {
        if(!adapter.selectDevice(vendorId, productId)){
          result.success(false);
        }else{
          result.success(true);
        }
    }


    public void closeConn(Result result) {
        adapter.closeConnectionIfExists();
        result.success(true);
    }


    public void printText(String text, Result result) {
        adapter.printText(text);
        result.success(true);
    }

    public void printRawData(String base64Data, Result result) {
        adapter.printRawData(base64Data);
        result.success(true);
    }

    public void write(final byte [] bytes, Result result) {
//        byte [] bytes = {1,2,3};
        adapter.write(bytes);
        result.success(true);
    }
}
