## A. Building
#### 1. Clone this repository
```sh
git clone https://github.com/rsuntk/android_kernel_samsung_a03-4.14-oss.git a03_kernel && cd a03_kernel && cd Rissu && chmod +x unpacker.sh && ./unpacker.sh
```
#### 2. Get required Toolchains:
- **For Galaxy A03 you need:**
  - [aarch64-linux-gnu](https://github.com/radcolor/aarch64-linux-gnu)
#### 3. Export these variable
```sh
export ANDROID_MAJOR_VERSION=t
export PLATFORM_VERSION=13
```
#### 4. Edit Makefile variable
```
CROSS_COMPILE=/path/to/aarch64-linux-gnu/bin/aarch64-linux-gnu-
CLANG_TRIPLE=/path/to/aarch64-linux-gnu/bin/aarch64-linux-gnu-
```
- **Reference:**
  - [CROSS_COMPILE](https://github.com/rsuntk/android_kernel_samsung_a03-4.14-oss/blob/android-4.14-stable/Makefile#L321)
  - [CLANG_TRIPLE](https://github.com/rsuntk/android_kernel_samsung_a03-4.14-oss/blob/android-4.14-stable/Makefile#L492)
#### 5. Edit `arch/arm64/config/rissu_defconfig`
```
CONFIG_LOCALVERSION="-YourKernelSringsName"
# CONFIG_LOCALVERSION_AUTO is not set
```
#### 6. Get this [build script](https://github.com/rsuntk/kernel-build-script) or type
```sh
make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y rissu_defconfig && make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y
```
#### 7. Check directory out/arch/arm64/boot
```sh
cd $(pwd)/out/arch/arm64/boot && ls
Image.gz - Kernel is compressed with gzip algorithm
Image    - Kernel is uncompressed, but you can put this to AnyKernel3 flasher
```
#### 8. Put Image.gz/Image to Anykernel3 zip, don't forget to modify the boot partition path in anykernel.sh
#### 9. Done, enjoy.
## B. How to add [KernelSU](https://kernelsu.org) support
#### 1. First, add KernelSU to your kernel source tree:
```sh
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
```
#### 2. Disable KPROBE. Edit ```arch/arm64/configs/rissu_defconfig```, and the edit these lines
> KPROBE sometimes broken in a few device, so we need to disable it and use manual integration.

**From this:**
```
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
```
**To this:**
```
# CONFIG_KPROBES is not set
# CONFIG_HAVE_KPROBES is not set
# CONFIG_KPROBE_EVENTS is not set
```
#### 3. Then add KernelSU config line
```
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set # if you a dev, then turn on this option for KernelSU debugging.
```
#### 4. Edit these file:
- **NOTE: KernelSU depends on these symbols:***
	- ```do_execveat_common```
	- ```faccessat```
	- ```vfs_read```
	- ```vfs_statx```
	- ```input_handle_event```

- **fs/exec.c**
```diff
--- exec_original.c	2024-01-16 15:46:58.596960146 +0700
+++ exec_patched.c	2024-01-16 15:46:11.847964612 +0700
@@ -1696,6 +1696,13 @@
 /*
  * sys_execve() executes a new program.
  */
+#ifdef CONFIG_KSU
+extern bool ksu_execveat_hook __read_mostly;
+extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,
+			void *envp, int *flags);
+extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,
+				 void *argv, void *envp, int *flags);
+#endif
 static int do_execveat_common(int fd, struct filename *filename,
 			      struct user_arg_ptr argv,
 			      struct user_arg_ptr envp,
@@ -1707,6 +1714,12 @@
 	struct files_struct *displaced;
 	int retval;
 
+#ifdef CONFIG_KSU
+	if (unlikely(ksu_execveat_hook))
+		ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
+	else
+		ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);
+#endif
 	if (IS_ERR(filename))
 		return PTR_ERR(filename);
```
- **fs/open.c**
```diff
--- open_original.c	2023-09-08 15:17:15.000000000 +0700
+++ open_patched.c	2024-01-16 15:50:04.392916738 +0700
@@ -359,6 +359,11 @@
  * We do this by temporarily clearing all FS-related capabilities and
  * switching the fsuid/fsgid around to the real ones.
  */
+
+#ifdef CONFIG_KSU
+extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,
+			 int *flags);
+#endif
 SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)
 {
 	const struct cred *old_cred;
@@ -368,6 +373,10 @@
 	struct vfsmount *mnt;
 	int res;
 	unsigned int lookup_flags = LOOKUP_FOLLOW;
+	
+#ifdef CONFIG_KSU
+	ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
+#endif
 
 	if (mode & ~S_IRWXO)	/* where's F_OK, X_OK, W_OK, R_OK? */
 		return -EINVAL;
```
- **fs/read_write.c**
```diff
--- read_write_original.c	2023-09-08 15:17:15.000000000 +0700
+++ read_write_patched.c	2024-01-16 15:52:02.483431515 +0700
@@ -429,9 +429,20 @@
 }
 EXPORT_SYMBOL(kernel_read);
 
+#ifdef CONFIG_KSU
+extern bool ksu_vfs_read_hook __read_mostly;
+extern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr,
+			size_t *count_ptr, loff_t **pos);
+#endif
+
 ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)
 {
 	ssize_t ret;
+	
+#ifdef CONFIG_KSU 
+	if (unlikely(ksu_vfs_read_hook))
+		ksu_handle_vfs_read(&file, &buf, &count, &pos);
+#endif
 
 	if (!(file->f_mode & FMODE_READ))
 		return -EBADF;
```
- **fs/stat.c**
```diff
--- stat_original.c	2023-09-08 15:17:15.000000000 +0700
+++ stat_patched.c	2024-01-16 15:54:01.894012909 +0700
@@ -163,6 +163,10 @@
  *
  * 0 will be returned on success, and a -ve error code if unsuccessful.
  */
+#ifdef CONFIG_KSU
+extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);
+#endif
+
 int vfs_statx(int dfd, const char __user *filename, int flags,
 	      struct kstat *stat, u32 request_mask)
 {
@@ -170,6 +174,9 @@
 	int error = -EINVAL;
 	unsigned int lookup_flags = LOOKUP_FOLLOW | LOOKUP_AUTOMOUNT;
 
+#ifdef CONFIG_KSU
+	ksu_handle_stat(&dfd, &filename, &flags);
+#endif
 	if ((flags & ~(AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT |
 		       AT_EMPTY_PATH | KSTAT_QUERY_FLAGS)) != 0)
 		return -EINVAL;
```
- **drivers/input/input.c**
```diff
diff --git a/drivers/input/input.c b/drivers/input/input.c
index 45306f9ef247..815091ebfca4 100755
--- a/drivers/input/input.c
+++ b/drivers/input/input.c
@@ -367,10 +367,13 @@ static int input_get_disposition(struct input_dev *dev,
 	return disposition;
 }
+#ifdef CONFIG_KSU
+extern bool ksu_input_hook __read_mostly;
+extern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);
+#endif

 static void input_handle_event(struct input_dev *dev,
 			       unsigned int type, unsigned int code, int value)
 {
	int disposition = input_get_disposition(dev, type, code, &value);
	
+#ifdef CONFIG_KSU
+	if (unlikely(ksu_input_hook))
+		ksu_handle_input_handle_event(&type, &code, &value);
+#endif

 	if (disposition != INPUT_IGNORE_EVENT && type != EV_SYN)
 		add_input_randomness(type, code, value);
```
- **See full KernelSU non-GKI integration documentations** [here](https://kernelsu.org/guide/how-to-integrate-for-non-gki.html)

## C. Problem solving
#### Q: I get an error in drivers/gpu/arm/Kconfig
A: Export [these variable](https://github.com/rsuntk/android_kernel_samsung_a12s-4.19-rebased#3-export-these-variable)

#### Q: I get an error "drivers/kernelsu/Kconfig"
A: Make sure symlinked ksu folder are there.

#### Q: I get undefined reference at ksu related lines.
A: Check out/drivers/kernelsu, if everything not compiled then, check drivers/Makefile, make sure ```obj-$(CONFIG_KSU) += kernelsu/``` are there.
## D. Credit
- [Rissu](https://github.com/rsuntk) - Rebased kernel source
- [KernelSU](https://kernelsu.org) - A kernel-based root solution for Android
