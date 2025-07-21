//
// MATLAB Compiler: 6.2 (R2016a)
// Date: Thu Jul 12 14:36:10 2018
// Arguments: "-B" "macro_default" "-W" "cpplib:libcorrlin" "-T" "link:lib"
// "corrlin.m" 
//

#ifndef __libcorrlin_h
#define __libcorrlin_h 1

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

#ifdef EXPORTING_libcorrlin
#define PUBLIC_libcorrlin_C_API __global
#else
#define PUBLIC_libcorrlin_C_API /* No import statement needed. */
#endif

#define LIB_libcorrlin_C_API PUBLIC_libcorrlin_C_API

#elif defined(_HPUX_SOURCE)

#ifdef EXPORTING_libcorrlin
#define PUBLIC_libcorrlin_C_API __declspec(dllexport)
#else
#define PUBLIC_libcorrlin_C_API __declspec(dllimport)
#endif

#define LIB_libcorrlin_C_API PUBLIC_libcorrlin_C_API


#else

#define LIB_libcorrlin_C_API

#endif

/* This symbol is defined in shared libraries. Define it here
 * (to nothing) in case this isn't a shared library. 
 */
#ifndef LIB_libcorrlin_C_API 
#define LIB_libcorrlin_C_API /* No special import/export declaration */
#endif

extern LIB_libcorrlin_C_API 
bool MW_CALL_CONV libcorrlinInitializeWithHandlers(
       mclOutputHandlerFcn error_handler, 
       mclOutputHandlerFcn print_handler);

extern LIB_libcorrlin_C_API 
bool MW_CALL_CONV libcorrlinInitialize(void);

extern LIB_libcorrlin_C_API 
void MW_CALL_CONV libcorrlinTerminate(void);



extern LIB_libcorrlin_C_API 
void MW_CALL_CONV libcorrlinPrintStackTrace(void);

extern LIB_libcorrlin_C_API 
bool MW_CALL_CONV mlxCorrlin(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);


#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

/* On Windows, use __declspec to control the exported API */
#if defined(_MSC_VER) || defined(__BORLANDC__)

#ifdef EXPORTING_libcorrlin
#define PUBLIC_libcorrlin_CPP_API __declspec(dllexport)
#else
#define PUBLIC_libcorrlin_CPP_API __declspec(dllimport)
#endif

#define LIB_libcorrlin_CPP_API PUBLIC_libcorrlin_CPP_API

#else

#if !defined(LIB_libcorrlin_CPP_API)
#if defined(LIB_libcorrlin_C_API)
#define LIB_libcorrlin_CPP_API LIB_libcorrlin_C_API
#else
#define LIB_libcorrlin_CPP_API /* empty! */ 
#endif
#endif

#endif

extern LIB_libcorrlin_CPP_API void MW_CALL_CONV corrlin(int nargout, mwArray& r, mwArray& dr, const mwArray& theta, const mwArray& d);

#endif
#endif
