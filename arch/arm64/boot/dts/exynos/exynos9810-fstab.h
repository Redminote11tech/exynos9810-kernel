/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __EXYNOS9810_FSTAB_H
#define __EXYNOS9810_FSTAB_H

#ifdef CONFIG_EXYNOS9810_EROFS_FSTAB
#define EXYNOS9810_SYSTEM_FS_TYPE "erofs"
#else
#define EXYNOS9810_SYSTEM_FS_TYPE "ext4"
#endif

#endif
