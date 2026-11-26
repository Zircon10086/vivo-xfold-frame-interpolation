package de.robv.android.xposed;

import android.app.Application;
import android.content.pm.ApplicationInfo;

/** 编译用最小桩：真实实现在 Vector/LSPosed 运行时提供。 */
public interface IXposedHookLoadPackage {
    void handleLoadPackage(LoadPackageParam lpparam) throws Throwable;

    class LoadPackageParam {
        public String packageName;
        public String processName;
        public ClassLoader classLoader;
        public ApplicationInfo appInfo;
        public boolean isFirstApplication;
    }
}
