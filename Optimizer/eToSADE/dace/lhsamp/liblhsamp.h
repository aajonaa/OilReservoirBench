//
// MATLAB Compiler: 6.2 (R2016a)
// Date: Thu Jul 12 15:11:35 2018
// Arguments: "-B" "macro_default" "-W" "cpplib:liblhsamp" "-T" "link:lib"
// "lhsamp.m" 
//

#ifndef __liblhsamp_h
#define __liblhsamp_h 1

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

#ifdef EXPORTING_liblhsamp
#define PUBLIC_liblhsamp_C_API __global
#else
#define PUBLIC_liblhsamp_C_API /* No import statement needed. */
#endif

#define LIB_liblhsamp_C_API PUBLIC_liblhsamp_C_API

#elif defined(_HPUX_SOURCE)

#ifdef EXPORTING_liblhsamp
#define PUBLIC_liblhsamp_C_API __declspec(dllexport)
#else
#define PUBLIC_liblhsamp_C_API __declspec(dllimport)
#endif

#define LIB_liblhsamp_C_API PUBLIC_liblhsamp_C_API


#else

#define LIB_liblhsamp_C_API

#endif

/* This symbol is defined in shared libraries. Define it here
 * (to nothing) in case this isn't a shared library. 
 */
#ifndef LIB_liblhsamp_C_API 
#define LIB_liblhsamp_C_API /* No special import/export declaration */
#endif

extern LIB_liblhsamp_C_API 
bool MW_CALL_CONV liblhsampInitializeWithHandlers(
       mclOutputHandlerFcn error_handler, 
       mclOutputHandlerFcn print_handler);

extern LIB_liblhsamp_C_API 
bool MW_CALL_CONV liblhsampInitialize(void);

extern LIB_liblhsamp_C_API 
void MW_CALL_CONV liblhsampTerminate(void);



extern LIB_liblhsamp_C_API 
void MW_CALL_CONV liblhsampPrintStackTrace(void);

extern LIB_liblhsamp_C_API 
bool MW_CALL_CONV mlxLhsamp(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);


#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

/* On Windows, use __declspec to control the exported API */
#if defined(_MSC_VER) || defined(__BORLANDC__)

#ifdef EXPORTING_liblhsamp
#define PUBLIC_liblhsamp_CPP_API __declspec(dllexport)
#else
#define PUBLIC_liblhsamp_CPP_API __declspec(dllimport)
#endif

#define LIB_liblhsamp_CPP_API PUBLIC_liblhsamp_CPP_API

#else

#if !defined(LIB_liblhsamp_CPP_API)
#if defined(LIB_liblhsamp_C_API)
#define LIB_liblhsamp_CPP_API LIB_liblhsamp_C_API
#else
#define LIB_liblhsamp_CPP_API /* empty! */ 
#endif
#endif

#endif

extern LIB_liblhsamp_CPP_API void MW_CALL_CONV lhsamp(int nargout, mwArray& S, const mwArray& m, const mwArray& n);

#endif
#endif
