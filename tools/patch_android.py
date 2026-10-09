"""Applies our Android settings to the project made by `flutter create`."""
import glob, os, re, shutil
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
app = os.path.join(root, "app", "android", "app")
patch = os.path.join(root, "android_patch")

# 1) manifest (permissions, Health Connect, reminders, app name)
shutil.copy(os.path.join(patch, "AndroidManifest.xml"), os.path.join(app, "src", "main", "AndroidManifest.xml"))

# 2) MainActivity must be a FlutterFragmentActivity (Health Connect needs it)
for f in glob.glob(os.path.join(app, "src", "main", "kotlin", "**", "MainActivity.kt"), recursive=True):
    pkg = open(f).read().splitlines()[0]
    open(f, "w").write(pkg + "\n\nimport io.flutter.embedding.android.FlutterFragmentActivity\n\nclass MainActivity : FlutterFragmentActivity()\n")
    print("patched", f)

# 3) gradle: minSdk 26, desugaring, stable debug signing for release
g = os.path.join(app, "build.gradle.kts")
s = open(g).read()
s = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 26", s, count=1)
if "isCoreLibraryDesugaringEnabled" not in s:
    s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
if "desugar_jdk_libs" not in s:
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
open(g, "w").write(s)
print(s)

# 4) launcher icons
res = os.path.join(patch, "res")
if os.path.isdir(res):
    for d in os.listdir(res):
        for f in os.listdir(os.path.join(res, d)):
            os.makedirs(os.path.join(app, "src", "main", "res", d), exist_ok=True)
            shutil.copy(os.path.join(res, d, f), os.path.join(app, "src", "main", "res", d, f))
    print("icons copied")
