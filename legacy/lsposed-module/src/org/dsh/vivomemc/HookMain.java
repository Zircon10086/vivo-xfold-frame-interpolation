package org.dsh.vivomemc;

import android.content.Context;
import android.util.Log;

import java.util.Arrays;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;

/**
 * v0.3
 *
 * 目标：让 PD2266（X Fold 2）跑「60 → 120」插帧档。
 *
 * GameCube（com.vivo.gamecube，含 :assistantui）：
 *  1) FtFeature 能力位强制 true（memc / aisr）；
 *  2) e0.p0 游戏适配强制 true；
 *  3) frameinterpolation.i.c 原生帧率恒 60（侧栏「需高帧率」提示的判定值）；
 *  4) e9.i.b 在 BOOST_FRAME 时直接返回 {60,120,60}（绕开 support_sdk=0 时三段 if 把 120 覆盖成 60）；
 *  5) e9.k 能力位：放行 30_120 / 60_120，关掉 30_60 与 60_48_144（面板 120Hz，144 不可用）；
 *  6) com.vivo.common.utils.l0.b 是唯一写 Settings 的点，兜底把 target>=120 的请求钉成 60:120。
 *
 * GameWatch（com.vivo.gamewatch）：
 *  7) e0.a.o 把 6 参 258 报文补成 7 参（本机走旧 IC 分支，原报文不含目标帧率字段）；
 *     7 参布局（系统 NovaUsecaseControllerV1 case 258, count>=7）：[0..3] pid/flags、[4] memcFps、[5] dfps、[6] targetFps。
 *  8) j0.l 的 Y()/N() 只打日志，不改行为，便于真机定位闸门。
 */
public class HookMain implements IXposedHookLoadPackage {

    private static final String TAG = "[VivoMemc] ";
    private static final String LOGCAT_TAG = "VivoMemc";

    /** 双写：android.util.Log 保证 logcat 可见；XposedBridge.log 进框架日志。 */
    static void log(String msg) {
        Log.e(LOGCAT_TAG, msg);
        XposedBridge.log(TAG + msg);
    }
    private static final int TYPE_GAME_MEMC = 258;

    private static int sLastMeasured = Integer.MIN_VALUE;

    @Override
    public void handleLoadPackage(LoadPackageParam lpparam) {
        String pkg = lpparam.packageName;
        if ("com.vivo.gamecube".equals(pkg)) {
            log("inject gamecube (" + lpparam.processName + ")");
            hookCapability(lpparam.classLoader, pkg);
            hookGameSupport(lpparam.classLoader);
            hookNativeFps(lpparam.classLoader);
            hookBoostTarget(lpparam.classLoader);
            hookSceneFlags(lpparam.classLoader);
            hookSettingsWriter(lpparam.classLoader);
        } else if ("com.vivo.gamewatch".equals(pkg)) {
            log("inject gamewatch (" + lpparam.processName + ")");
            hookCapability(lpparam.classLoader, pkg);
            hookEnhancePayload(lpparam.classLoader);
            hookAdjusterDiagnostics(lpparam.classLoader);
        }
    }

    private void hookCapability(final ClassLoader cl, final String pkg) {
        try {
            XposedHelpers.findAndHookMethod("android.util.FtFeature", cl,
                    "isFeatureSupport", String.class, new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            Object arg = param.args[0];
                            if ("vivo.hardware.game.memc".equals(arg)
                                    || "vivo.hardware.game.aisr".equals(arg)) {
                                param.setResult(Boolean.TRUE);
                            }
                        }
                    });
        } catch (Throwable t) {
            log(pkg + " hook FtFeature failed: " + t);
        }
    }

    private void hookGameSupport(final ClassLoader cl) {
        try {
            XposedHelpers.findAndHookMethod("com.vivo.gameassistant.utils.e0", cl,
                    "p0", String.class, new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            param.setResult(Boolean.TRUE);
                        }
                    });
        } catch (Throwable t) {
            log("hook e0.p0 failed: " + t);
        }
    }

    private void hookNativeFps(final ClassLoader cl) {
        try {
            XposedHelpers.findAndHookMethod(
                    "com.vivo.gameassistant.frameinterpolation.i", cl,
                    "c", Context.class, String.class, new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            param.setResult(60);
                        }
                    });
        } catch (Throwable t) {
            log("hook i.c failed: " + t);
        }
    }

    /** e9.i.b(Context,int,int,int,FrameInterpolationState) → int[]{depress, target, gameFps} */
    private void hookBoostTarget(final ClassLoader cl) {
        final Class<?> stateCls;
        try {
            stateCls = Class.forName(
                    "com.vivo.gameassistant.frameinterpolation.FrameInterpolationState", false, cl);
        } catch (Throwable t) {
            log("load FrameInterpolationState failed: " + t);
            return;
        }
        try {
            XposedHelpers.findAndHookMethod("e9.i", cl, "b",
                    Context.class, int.class, int.class, int.class, stateCls,
                    new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            Object state = param.args[4];
                            String name = state instanceof Enum ? ((Enum<?>) state).name() : "";
                            Object orig = param.getResult();
                            log("e9.i.b state=" + name + " native=" + param.args[1]
                                    + " result=" + Arrays.toString((int[]) orig));
                            if ("BOOST_FRAME".equals(name)) {
                                param.setResult(new int[]{60, 120, 60});
                                log("boost target -> 60/120");
                            }
                        }
                    });
        } catch (Throwable t) {
            log("hook e9.i.b failed: " + t);
        }
    }

    /** e9.k 的能力位：b=30_120, c=30_60, d=60_120, f=60_48_144 */
    private void hookSceneFlags(final ClassLoader cl) {
        hookConst(cl, "b", Boolean.TRUE);
        hookConst(cl, "c", Boolean.FALSE);
        hookConst(cl, "d", Boolean.TRUE);
        hookConst(cl, "f", Boolean.FALSE);
    }

    private void hookConst(final ClassLoader cl, final String method, final Boolean value) {
        try {
            XposedHelpers.findAndHookMethod("e9.k", cl, method, String.class, new XC_MethodHook() {
                @Override
                protected void afterHookedMethod(MethodHookParam param) {
                    param.setResult(value);
                }
            });
        } catch (Throwable t) {
            log("hook e9.k." + method + " failed: " + t);
        }
    }

    /** com.vivo.common.utils.l0.b(Context, boolean on, int gameIndex, int pid, int depress, int target) */
    private void hookSettingsWriter(final ClassLoader cl) {
        try {
            XposedHelpers.findAndHookMethod("com.vivo.common.utils.l0", cl, "b",
                    Context.class, boolean.class, int.class, int.class, int.class, int.class,
                    new XC_MethodHook() {
                        @Override
                        protected void beforeHookedMethod(MethodHookParam param) {
                            boolean on = (Boolean) param.args[1];
                            int depress = (Integer) param.args[4];
                            int target = (Integer) param.args[5];
                            log("settings write on=" + on
                                    + " depress=" + depress + " target=" + target);
                            if (on && target >= 100) {
                                param.args[4] = 60;
                                param.args[5] = 120;
                                log("settings write forced 60:120");
                            }
                        }
                    });
        } catch (Throwable t) {
            log("hook l0.b failed: " + t);
        }
    }

    /** e0.a.o(int,int[])：旧 IC 分支只发 6 个 int，这里补第 7 位目标帧率。 */
    private void hookEnhancePayload(final ClassLoader cl) {
        try {
            XposedHelpers.findAndHookMethod("e0.a", cl, "o",
                    int.class, int[].class, new XC_MethodHook() {
                        @Override
                        protected void beforeHookedMethod(MethodHookParam param) {
                            int type = (Integer) param.args[0];
                            int[] values = (int[]) param.args[1];
                            if (type != TYPE_GAME_MEMC || values == null) {
                                return;
                            }
                            log("ic 258 " + Arrays.toString(values));
                            if (values.length != 6 || values[0] != 10) {
                                return;
                            }
                            int dfps = values[5];
                            int tfps;
                            if (dfps == 30) {
                                tfps = 60;
                            } else if (dfps == 45) {
                                tfps = 90;
                            } else if (dfps == 60) {
                                tfps = 120;
                            } else if (dfps == 48 || dfps == 72) {
                                // 面板 120Hz，144 不可用：按 60→120 档送
                                dfps = 60;
                                tfps = 120;
                            } else {
                                dfps = 60;
                                tfps = 120;
                            }
                            int[] expanded = Arrays.copyOf(values, 7);
                            expanded[5] = dfps;
                            expanded[6] = tfps;
                            param.args[1] = expanded;
                            log("payload -> " + Arrays.toString(expanded));
                        }
                    });
        } catch (Throwable t) {
            log("hook e0.a.o failed: " + t);
        }
    }

    /** 只读诊断：j0.l.Y(int,int,c) / N(c) 的判定结果，便于真机定位闸门。 */
    private void hookAdjusterDiagnostics(final ClassLoader cl) {
        final Class<?> cCls;
        try {
            // jadx 把内部类 l$c 输出成 j0/c.java，运行时类名是 j0.l$c
            cCls = Class.forName("j0.l$c", false, cl);
        } catch (Throwable t) {
            log("load j0.l$c failed: " + t);
            return;
        }
        try {
            XposedHelpers.findAndHookMethod("j0.l", cl, "Y",
                    int.class, int.class, cCls, new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            log("Y(" + param.args[0] + "," + param.args[1] + ")="
                                    + param.getResult());
                        }
                    });
        } catch (Throwable t) {
            log("hook j0.l.Y failed: " + t);
        }
        try {
            XposedHelpers.findAndHookMethod("j0.l", cl, "N", cCls, new XC_MethodHook() {
                @Override
                protected void afterHookedMethod(MethodHookParam param) {
                    log("N()=" + param.getResult());
                }
            });
        } catch (Throwable t) {
            log("hook j0.l.N failed: " + t);
        }
    }
}
