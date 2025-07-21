//
// MATLAB Compiler: 6.2 (R2016a)
// Date: Thu Jul 12 13:53:38 2018
// Arguments: "-B" "macro_default" "-W" "cpplib:libdacefit" "-T" "link:lib"
// "dacefit.m" 
//

#ifndef __libdacefit_h
#define __libdacefit_h 1

#if defined(__cplusplus) && !defined(mclmcrrt_h) && defined(__linux__)
#  pragma implementation "mclmcrrt.h"
#endif
#include "mclmcrrt.h"
#include "mclcppclass.h"
#ifdef __cplusplus
extern "C" {
#endif

#if defined(__SUNPRO_CC)
/* Solaris shared libraries use __global, rather than mapfiles
 * to define the API exported from a shared library. __global is
 * only necessary when building the library -- files including
 * this header file to use the library do not need the __global
 * declaration; hence the EXPORTING_<library> logic.
 */

#ifdef EXPORTING_libdacefit
#define PUBLIC_libdacefit_C_API __global
#else
#define PUBLIC_libdacefit_C_API /* No import statement needed. */
#endif

#define LIB_libdacefit_C_API PUBLIC_libdacefit_C_API

#elif defined(_HPUX_SOURCE)

#ifdef EXPORTING_libdacefit
#define PUBLIC_libdacefit_C_API __declspec(dllexport)
#else
#define PUBLIC_libdacefit_C_API __declspec(dllimport)
#endif

#define LIB_libdacefit_C_API PUBLIC_libdacefit_C_API


#else

#define LIB_libdacefit_C_API

#endif

/* This symbol is defined in shared libraries. Define it here
 * (to nothing) in case this isn't a shared library. 
 */
#ifndef LIB_libdacefit_C_API 
#define LIB_libdacefit_C_API /* No special import/export declaration */
#endif

extern LIB_libdacefit_C_API 
bool MW_CALL_CONV libdacefitInitializeWithHandlers(
       mclOutputHandlerFcn error_handler, 
       mclOutputHandlerFcn print_handler);

extern LIB_libdacefit_C_API 
bool MW_CALL_CONV libdacefitInitialize(void);

extern LIB_libdacefit_C_API 
void MW_CALL_CONV libdacefitTerminate(void);



extern LIB_libdacefit_C_API 
void MW_CALL_CONV libdacefitPrintStackTrace(void);

extern LIB_libdacefit_C_API 
bool MW_CALL_CONV mlxDacefit(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);


#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

/* On Windows, use __declspec to control the exported API */
#if defined(_MSC_VER) || defined(__BORLANDC__)

#ifdef EXPORTING_libdacefit
#define PUBLIC_libdacefit_CPP_API __declspec(dllexport)
#else
#define PUBLIC_libdacefit_CPP_API __declspec(dllimport)
#endif

#define LIB_libdacefit_CPP_API PUBLIC_libdacefit_CPP_API

#else

#if !defined(LIB_libdacefit_CPP_API)
#if defined(LIB_libdacefit_C_API)
#define LIB_libdacefit_CPP_API LIB_libdacefit_C_API
#else
#define LIB_libdacefit_CPP_API /* empty! */ 
#endif
#endif

#endif

extern LIB_libdacefit_CPP_API void MW_CALL_CONV dacefit(int nargout, mwArray& dmodel, mwArray& perf, const mwArray& S, const mwArray& Y, const mwArray& regr, const mwArray& corr, const mwArray& theta0, const mwArray& lob, const mwArray& upb);

#endif
#endif
