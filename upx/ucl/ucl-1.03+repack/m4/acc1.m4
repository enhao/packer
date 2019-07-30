# serial 1

# /***********************************************************************
# // standard ACC macros
# ************************************************************************/

AC_DEFUN([mfx_ACC_CHECK_ENDIAN], [
AC_C_BIGENDIAN([AC_DEFINE(ACC_ENDIAN_BIG_ENDIAN,1,[Define to 1 if your machine is big endian.])],[AC_DEFINE(ACC_ENDIAN_LITTLE_ENDIAN,1,[Define to 1 if your machine is little endian.])])
])#

AC_DEFUN([mfx_ACC_CHECK_HEADERS], [
AC_HEADER_TIME
AC_CHECK_HEADERS([assert.h ctype.h dirent.h errno.h fcntl.h limits.h malloc.h memory.h setjmp.h signal.h stdarg.h stddef.h stdint.h stdio.h stdlib.h string.h strings.h time.h unistd.h utime.h sys/stat.h sys/time.h sys/types.h])
])#

AC_DEFUN([mfx_ACC_CHECK_FUNCS], [
AC_CHECK_FUNCS(access alloca atexit atoi atol chmod chown ctime difftime fstat gettimeofday gmtime localtime longjmp lstat memcmp memcpy memmove memset mktime qsort raise setjmp signal snprintf strcasecmp strchr strdup strerror strftime stricmp strncasecmp strnicmp strrchr strstr time umask utime vsnprintf)
])#


AC_DEFUN([mfx_ACC_CHECK_SIZEOF], [
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)

AC_CHECK_SIZEOF(ptrdiff_t)
AC_CHECK_SIZEOF(size_t)
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(char *)

AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF(unsigned long long)
AC_CHECK_SIZEOF(__int64)
AC_CHECK_SIZEOF(unsigned __int64)
])#


# /***********************************************************************
# // Check for ACC_conformance
# ************************************************************************/

AC_DEFUN([mfx_ACC_ACCCHK], [
mfx_tmp=$1
mfx_save_CPPFLAGS=$CPPFLAGS
dnl in Makefile.in $(INCLUDES) will be before $(CPPFLAGS), so we mimic this here
test "X$mfx_tmp" = "X" || CPPFLAGS="$mfx_tmp $CPPFLAGS"

AC_MSG_CHECKING([whether your compiler passes the ACC conformance test])

AC_LANG_CONFTEST([AC_LANG_PROGRAM(
[[#define ACC_CONFIG_NO_HEADER 1
#include "acc/acc.h"
#include "acc/acc_incd.h"
#undef ACCCHK_ASSERT
#define ACCCHK_ASSERT(expr)     ACC_COMPILE_TIME_ASSERT_HEADER(expr)
#include "acc/acc_chk.ch"
#undef ACCCHK_ASSERT
static void test_acc_compile_time_assert(void) {
#define ACCCHK_ASSERT(expr)     ACC_COMPILE_TIME_ASSERT(expr)
#include "acc/acc_chk.ch"
#undef ACCCHK_ASSERT
}
#undef NDEBUG
#include <assert.h>
static int test_acc_run_time_assert(int r) {
#define ACCCHK_ASSERT(expr)     assert(expr);
#include "acc/acc_chk.ch"
#undef ACCCHK_ASSERT
return r;
}
]], [[
test_acc_compile_time_assert();
if (test_acc_run_time_assert(1) != 1) return 1;
]]
)])

mfx_tmp=FAILED
_AC_COMPILE_IFELSE([], [mfx_tmp=yes])
rm -f conftest.$ac_ext conftest.$ac_objext

CPPFLAGS=$mfx_save_CPPFLAGS

AC_MSG_RESULT([$mfx_tmp])
case x$mfx_tmp in
  xpassed | xyes) ;;
  *)
    AC_MSG_NOTICE([])
    AC_MSG_NOTICE([Your compiler failed the ACC conformance test - for details see ])
    AC_MSG_NOTICE([`config.log'. Please check that log file and consider sending])
    AC_MSG_NOTICE([a patch or bug-report to <${PACKAGE_BUGREPORT}>.])
    AC_MSG_NOTICE([Thanks for your support.])
    AC_MSG_NOTICE([])
    AC_MSG_ERROR([ACC conformance test failed. Stop.])
dnl    AS_EXIT
    ;;
esac
])# mfx_ACC_ACCCHK
