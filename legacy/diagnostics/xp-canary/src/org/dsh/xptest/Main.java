package org.dsh.xptest;

import android.util.Log;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XposedBridge;

/** 注入探测器：只为回答「框架到底有没有把模块类加载进目标进程」。 */
public class Main implements IXposedHookLoadPackage {
    @Override
    public void handleLoadPackage(LoadPackageParam lpparam) {
        Log.e("XpTest", "loaded in " + lpparam.packageName + " proc=" + lpparam.processName);
        XposedBridge.log("[XpTest] loaded in " + lpparam.packageName);
    }
}
