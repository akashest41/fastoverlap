!    FASTOVERLAP
!
!    FORTRAN Module for calculating Fast SO(3) Fourier transforms (SOFTs)
!    Copyright (C) 2017  Matthew Griffiths
!    
!    This program is free software; you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation; either version 2 of the License, or
!    (at your option) any later version.
!    
!    This program is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!    
!    You should have received a copy of the GNU General Public License along
!    with this program; if not, write to the Free Software Foundation, Inc.,
!    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


!    Includes code from https://people.sc.fsu.edu/~jburkardt/f_src/special_functions/special_functions.html
!
!    Reference:
!
!    Shanjie Zhang, Jianming Jin,
!    Computation of Special Functions,
!    Wiley, 1996,
!    ISBN: 0-471-11963-6,
!    LC: QA351.C45.

INCLUDE "commons.f90"

INCLUDE "fastutils.f90"

! Module for performing discrete SO(3) transforms, depends on fftw.
INCLUDE "DSOFT.f90"


MODULE CLUSTERFASTOVERLAP

USE COMMONS, ONLY : PERMGROUP, NPERMSIZE, NPERMGROUP, NATOMS, BESTPERM, MYUNIT
USE FASTOVERLAPUTILS, ONLY : DUMMYA, DUMMYB, XBESTA, XBESTASAVE

LOGICAL, SAVE :: PERMINVOPTSAVE, NOINVERSIONSAVE

DOUBLE PRECISION, PARAMETER :: PI = 3.141592653589793D0

CONTAINS

SUBROUTINE HARMONIC0L(N, RJ, SIGMA, R0, RET)

IMPLICIT NONE
INTEGER, INTENT(IN) :: N
DOUBLE PRECISION, INTENT(IN) :: RJ, SIGMA, R0
DOUBLE PRECISION, INTENT(OUT) :: RET(0:N)

DOUBLE PRECISION R0SIGMA
INTEGER I,J,K

R0SIGMA = 1.D0/(R0**2+SIGMA**2)
RET(0) = SQRT(2.D0*SQRT(PI)*(R0*R0SIGMA)**3) * SIGMA**3 * EXP(-0.5D0*RJ**2*R0SIGMA)*4*PI

R0SIGMA = SQRT(2.D0) * R0 * RJ * R0SIGMA
DO I=1,N
    RET(I) = R0SIGMA / SQRT(1.D0+2.D0*I) * RET(I-1)
ENDDO

END SUBROUTINE HARMONIC0L

SUBROUTINE HARMONICNL(N,L,RJ,SIGMA,R0,RET)

!
! Calculates the value of the overlap integral up to N and L
!
! 4\pi \int_0^{\infty} g_{nl}(r)\exp{\left(-\frac{r^2+{r^p_j}^2}{2\sigma^2}\right)} 
! i_l \left( \frac{r r^p_{j}}{\sigma^2} \right) r^2\; \mathrm{d}r
!
! N is the maximum quantum number of the Harmonic basis to calculate up to
! L is the maximum angular moment number to calculate
! SIGMA is the width of the Gaussian Kernels
! R0 is the length scale of the Harmonic Basis
! RET is the matrix of calculate values of the overlap integral
!

IMPLICIT NONE
INTEGER, INTENT(IN) :: N, L
DOUBLE PRECISION, INTENT(IN) :: RJ, SIGMA, R0
DOUBLE PRECISION, INTENT(OUT) :: RET(0:N,0:L)

DOUBLE PRECISION R0SIGMA, RET2, SQRTI
INTEGER I,J,K

! Initiate Recurrence
R0SIGMA = 1.D0/(R0**2+SIGMA**2)
RET(0,0) = SQRT(2.D0*SQRT(PI)*(R0*R0SIGMA)**3) * SIGMA**3 * EXP(-0.5D0*RJ**2*R0SIGMA)*4*PI
R0SIGMA = SQRT(2.D0) * R0 * RJ * R0SIGMA
DO J=1,L
    RET(0,J) = R0SIGMA / SQRT(1.D0+2.D0*J) * RET(0,J-1)
ENDDO

R0SIGMA = SIGMA**2/RJ/R0
! When I=1 don't calculate RET(I-2,J)
I = 1
SQRTI = 1.D0 !SQRT(REAL(I,8))
DO J=0,L-2
!write(*,*) J, SQRT(I+J+0.5D0), (2.D0*J+3.D0)*SIGMA**2/RJ/R0, SQRT(I+J+1.5D0)
!write(*,*) J, RET(I-1,J), RET(I-1,J+1), RET(I-1,J+2)
!write(*,*) J, SQRT(I+J+0.5D0)*RET(I-1,J), (2.D0*J+3.D0)*SIGMA**2/RJ/R0 * RET(I-1,J+1), SQRT(I+J+1.5D0) * RET(I-1,J+2)
RET(I,J) = (SQRT(I+J+0.5D0)*RET(I-1,J) - (2.D0*J+3.D0)*SIGMA**2/RJ/R0 * RET(I-1,J+1) -&
    SQRT(I+J+1.5D0) * RET(I-1,J+2))/SQRTI
!write(*,*) J, RET(I,J)
ENDDO
! Assuming that integral for J>L = 0
!RET(I,L-1) = (SQRT(I+J+0.5D0)*RET(I-1,J) - (2.D0*J+3.D0)*SIGMA**2/RJ/R0 * RET(I-1,J+1))/SQRTI
!RET(I,L) = (SQRT(I+J+0.5D0)*RET(I-1,J))/SQRTI


DO I=2,N
SQRTI = SQRT(REAL(I,8))
DO J=0,L-2*I
RET(I,J) = (SQRT(I+J+0.5D0)*RET(I-1,J) - (2.D0*J+3.D0)*SIGMA**2/RJ/R0 * RET(I-1,J+1) -&
    SQRT(I+J+1.5D0) * RET(I-1,J+2) + SQRT(I-1.D0) * RET(I-2,J+2))/SQRTI
ENDDO
! Assuming that integral for J>L = 0
!RET(I,L-1) = (SQRT(I+J+0.5D0)*RET(I-1,J) - (2.D0*J+3.D0)*SIGMA**2/RJ/R0 * RET(I-1,J+1))/SQRTI
!RET(I,L) = (SQRT(I+J+0.5D0)*RET(I-1,J))/SQRTI
ENDDO

END SUBROUTINE HARMONICNL

SUBROUTINE LEGENDREL(PP,PM,PLMS,Z,L)
! Calculates values of Associated Legendre polynomial between
! P^{L-1}_L -> P^{-L+1}_L
! With PP = P^L_L and PM = P^{-L}_L
! Does this by solving a two term recurrence relation with PP and PM specifying
! the boundary conditions

IMPLICIT NONE

INTEGER, INTENT(IN) :: L
DOUBLE PRECISION, INTENT(IN) :: PP, PM, Z
DOUBLE PRECISION, INTENT(OUT) :: PLMS(2*L-1)

DOUBLE PRECISION :: D(2*L-1), DU(2*L-2), DL(2*L-2)
INTEGER INFO, J

DO J=0,2*L-2
    
ENDDO


END SUBROUTINE LEGENDREL

SUBROUTINE RYLM(COORD, R, YLM, L)

! Calculates the Spherical Harmonics associated with coordinate COORD
! up to L, returns R, the distance COORD is from origin
! Calculates value of Legendre Polynomial Recursively

IMPLICIT NONE

DOUBLE PRECISION, INTENT(IN) :: COORD(3)
INTEGER, INTENT(IN) :: L
DOUBLE PRECISION, INTENT(OUT) :: R
COMPLEX*16, INTENT(OUT) :: YLM(0:L,0:2*L)

INTEGER J, M, INDM1, INDM0, INDM2
DOUBLE PRECISION THETA, PHI, Z, FACTORIALS(0:2*L)
COMPLEX*16 EXPIM(0:2*L)
DOUBLE PRECISION, EXTERNAL :: RLEGENDREL0, RLEGENDREM0, RLEGENDREM1


R = (COORD(1)**2+COORD(2)**2+COORD(3)**2)**0.5
PHI = ATAN2(COORD(2), COORD(1))
Z = COORD(3)/R

!Calculating Associate Legendre Function
YLM = CMPLX(0.D0,0.D0, 8)
YLM(0,0) = (4*PI)**-0.5

! Calculating Factorials
FACTORIALS(0) = 1.D0
DO M=1,2*L
    FACTORIALS(M) = M*FACTORIALS(M-1)
ENDDO


! Initialising Recurrence for Associated Legendre Polynomials
DO J=0, L-1
    YLM(J+1,J+1) = RLEGENDREL0(J, Z) * YLM(J,J) !* ((2.D0*J+3,D0)/(2.D0*J+1.D0)/(2.D0*J+1.D0)/(2.D0*J+2.D0))
    YLM(J+1,J) = RLEGENDREM0(J+1,J+1,Z) * YLM(J+1,J+1)
ENDDO

! Recurrence for Associated Legendre Polynomials
DO J=1,L
    DO M=J-1,-J+1,-1
        INDM1 = MODULO(M+1, 2*L+1)
        INDM2 = MODULO(M-1, 2*L+1)
        INDM0 = MODULO(M, 2*L+1)
        YLM(J,INDM2) = RLEGENDREM0(M,J,Z) * YLM(J,INDM0) + RLEGENDREM1(M,J,Z) * YLM(J,INDM1)
    ENDDO
ENDDO

! Calculating exp(imPHI) component
DO M=-L,L
    INDM0 = MODULO(M, 2*L+1)
    EXPIM(INDM0) = EXP(CMPLX(0.D0, M*PHI, 8))
ENDDO

! Calculate Spherical Harmonics
DO J=1,L
    DO M=-J,J
        INDM0 = MODULO(M, 2*L+1)
        ! Could probably calculate the prefactor through another recurrence relation...
        YLM(J,INDM0) = EXPIM(INDM0)*YLM(J,INDM0) * ((2.D0*J+1.D0)*FACTORIALS(J-M)/FACTORIALS(J+M))**0.5
    ENDDO
ENDDO

END SUBROUTINE RYLM

SUBROUTINE RYML(COORD, R, YML, L)

! Calculates the Spherical Harmonics associated with coordinate COORD
! up to L, returns R, the distance COORD is from origin
! Calculates value of Legendre Polynomial Recursively

IMPLICIT NONE

DOUBLE PRECISION, INTENT(IN) :: COORD(3)
INTEGER, INTENT(IN) :: L
DOUBLE PRECISION, INTENT(OUT) :: R
COMPLEX*16, INTENT(OUT) :: YML(-L:L,0:L)

INTEGER J, M, INDM1, INDM0, INDM2
DOUBLE PRECISION THETA, PHI, Z, FACTORIALS(0:2*L), SQRTZ, SQRTMJ
COMPLEX*16 EXPIM(-L:L)

R = (COORD(1)**2+COORD(2)**2+COORD(3)**2)**0.5
PHI = ATAN2(COORD(2), COORD(1))
Z = COORD(3)/R
SQRTZ = SQRT(1.D0-Z**2)

! Calculating Factorials
FACTORIALS(0) = 1.D0
DO J=1,2*L
    FACTORIALS(J) = J*FACTORIALS(J-1)
ENDDO

!Calculating Associate Legendre Function
YML = CMPLX(0.D0,0.D0, 8)
YML(0,0) = (4*PI)**-0.5

! Initialising Recurrence for Associated Legendre Polynomials
! Calculating normalised Legendre Polynomials for better numerical stability
! Pnorm^m_l = \sqrt{(l-m)!/(l+m)!} P^m_l
DO J=0, L-1
    YML(J+1,J+1) = - SQRT((2.D0*J+1.D0)/(2.D0*J+2.D0)) * SQRTZ* YML(J,J)
    ! Calculating first recurrence term
    YML(J, J+1) = -SQRT(2.D0*(J+1))*Z/SQRTZ * YML(J+1, J+1)
ENDDO

!DO J=1,L
!    M = J
!    SQRTMJ = SQRT((J+M)*(J-M+1.D0))
!    YML(M-1, J) = -2*M*Z/SQRTMJ/SQRTZ * YML(M, J)
!ENDDO

! Recurrence for normalised Associated Legendre Polynomials
DO J=1,L
    DO M=J-1,-J+1,-1
        SQRTMJ = SQRT((J+M)*(J-M+1.D0))
        YML(M-1, J) = -2*M*Z/SQRTMJ/SQRTZ * YML(M, J) - SQRT((J-M)*(J+M+1.D0))/SQRTMJ * YML(M+1,J)
    ENDDO
ENDDO

! Calculating exp(imPHI) component
DO M=-L,L
    EXPIM(M) = EXP(CMPLX(0.D0, M*PHI, 8))
ENDDO

! Calculate Spherical Harmonics
DO J=1,L
    DO M=-J,J
        INDM0 = MODULO(M, 2*L+1)
        YML(M,J) = EXPIM(M)*YML(M,J) * SQRT((2.D0*J+1.D0))
    ENDDO
ENDDO

END SUBROUTINE RYML

SUBROUTINE HARMONICCOEFFS(COORDS, NATOMS, CNLM, N, L, HWIDTH, KWIDTH)

!
! For a set of Gaussian Kernels of width KWIDTH at COORDS, 
! this will calculate the coefficients of the isotropic quantum harmonic basis
! cnlm with length scale HWIDTH up to N and L.
!

IMPLICIT NONE

INTEGER, INTENT(IN) :: NATOMS, N, L
DOUBLE PRECISION, INTENT(IN) :: COORDS(3*NATOMS), HWIDTH, KWIDTH
COMPLEX*16, INTENT(OUT) :: CNLM(0:N,0:L,0:2*L)

COMPLEX*16 :: YLM(0:L,0:2*L)
DOUBLE PRECISION HARMCOEFFS(0:2*N+L,0:N,0:L), DNL(0:N,0:L+2*N), RJ
INTEGER I,J,K,SI,M,INDM, S

CNLM = CMPLX(0.D0,0.D0,8)

DO K=1,NATOMS
    CALL RYLM(COORDS(3*K-2:3*K), RJ, YLM, L)
    CALL HARMONICNL(N,L+2*N,RJ,KWIDTH,HWIDTH,DNL)
    DO J=0,L
        DO M=-J,J
            INDM = MODULO(M,2*L+1)
            DO I=0,N
            CNLM(I,J,INDM) = CNLM(I,J,INDM) + DNL(I,J) * CONJG(YLM(J,INDM))
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE HARMONICCOEFFS

SUBROUTINE HARMONICCOEFFSNML(COORDS, NATOMS, CNML, N, L, HWIDTH, KWIDTH)

!
! For a set of Gaussian Kernels of width KWIDTH at COORDS, 
! this will calculate the coefficients of the isotropic quantum harmonic basis
! cnlm with length scale HWIDTH up to N and L.
!

IMPLICIT NONE

INTEGER, INTENT(IN) :: NATOMS, N, L
DOUBLE PRECISION, INTENT(IN) :: COORDS(3*NATOMS), HWIDTH, KWIDTH
COMPLEX*16, INTENT(OUT) :: CNML(0:N,-L:L,0:L)

COMPLEX*16 :: YML(-L:L,0:L)
DOUBLE PRECISION HARMCOEFFS(0:2*N+L,0:N,0:L), DNL(0:N,0:L+2*N), RJ
INTEGER I,J,K,SI,M,INDM, S

CNML = CMPLX(0.D0,0.D0,8)

DO K=1,NATOMS
    CALL RYML(COORDS(3*K-2:3*K), RJ, YML, L)
    CALL HARMONICNL(N,L+2*N,RJ,KWIDTH,HWIDTH,DNL)
    DO J=0,L
        DO M=-J,J
            INDM = MODULO(M,2*L+1)
            DO I=0,N
                CNML(I,M,J) = CNML(I,M,J) + DNL(I,J) * CONJG(YML(M,J))
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE HARMONICCOEFFSNML

SUBROUTINE DOTHARMONICCOEFFS(C1NLM, C2NLM, N, L, ILMM)

IMPLICIT NONE

INTEGER, INTENT(IN) :: N, L
COMPLEX*16, INTENT(IN) :: C1NLM(0:N,0:L,0:2*L), C2NLM(0:N,0:L,0:2*L)
COMPLEX*16, INTENT(OUT) :: ILMM(0:L,0:2*L,0:2*L)

INTEGER I, J, M1, M2, INDM1, INDM2

ILMM = CMPLX(0.D0,0.D0,8)

DO J=0,L
    DO M1=-J,J
        INDM1 = MODULO(M1, 2*L+1)
        DO M2=-J,J
            INDM2 = MODULO(M2, 2*L+1)
            DO I=0,N
                ILMM(J,INDM1,INDM2) = ILMM(J,INDM1,INDM2) + CONJG(C1NLM(I,J,INDM1))*C2NLM(I,J,INDM2)
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE DOTHARMONICCOEFFS

SUBROUTINE DOTHARMONICCOEFFSNML(C1NML, C2NML, N, L, IMML)

IMPLICIT NONE

INTEGER, INTENT(IN) :: N, L
COMPLEX*16, INTENT(IN) :: C1NML(0:N,-L:L,0:L), C2NML(0:N,-L:L,0:L)
COMPLEX*16, INTENT(OUT) :: IMML(-L:L,-L:L,0:L)

INTEGER I, J, M1, M2, INDM1, INDM2

IMML = CMPLX(0.D0,0.D0,8)

DO J=0,L
    DO M2=-J,J
        DO M1=-J,J
            DO I=0,N
                IMML(M1,M2,J) = IMML(M1,M2,J) + CONJG(C1NML(I,M1,J))*C2NML(I,M2,J)
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE DOTHARMONICCOEFFSNML

SUBROUTINE FOURIERCOEFFS(COORDSB, COORDSA, NATOMS, L, KWIDTH, ILMM)
!
! Calculates S03 Coefficients of the overlap integral of two structures
! does this calculation by direct calculation of the overlap between every pair
! of atoms, slower than the Harmonic basis, but slightly more accurate.
!

IMPLICIT NONE
DOUBLE PRECISION, INTENT(IN) :: COORDSA(3*NATOMS), COORDSB(3*NATOMS), KWIDTH
INTEGER, INTENT(IN) :: NATOMS, L
COMPLEX*16, INTENT(OUT) :: ILMM(0:L,0:2*L,0:2*L)

COMPLEX*16 YLMA(0:L,0:2*L,NATOMS), YLMB(0:L,0:2*L,NATOMS)
DOUBLE PRECISION RA(NATOMS), RB(NATOMS), IL(0:L), R1R2, EXPRA(NATOMS), EXPRB(NATOMS), FACT, TMP

INTEGER IA,IB,I,J,K,M1,M2,INDM1,INDM2

! Precalculate some values
DO I=1,NATOMS
    CALL RYLM(COORDSA(3*I-2:3*I), RA(I), YLMA(:,:,I), L)
    CALL RYLM(COORDSB(3*I-2:3*I), RB(I), YLMB(:,:,I), L)
    EXPRA(I) = EXP(-0.25D0 * RA(I)**2 / KWIDTH**2)
    EXPRB(I) = EXP(-0.25D0 * RB(I)**2 / KWIDTH**2)
ENDDO


FACT = 4.D0 * PI**2.5 * KWIDTH**3

ILMM = CMPLX(0.D0,0.D0,8)
DO IA=1,NATOMS
    DO IB=1,NATOMS
        R1R2 = 0.5D0 * RA(IA)*RB(IB)/KWIDTH**2
        CALL SPHI(L, R1R2, K, IL)
        TMP = FACT*EXPRA(IA)*EXPRB(IB)
        DO J=0,L
            DO M2=-L,L
                INDM2 = MODULO(M2, 2*L+1)
                DO M1=-L,L
                    INDM1 = MODULO(M1, 2*L+1)
                    ILMM(J,INDM1,INDM2) = ILMM(J,INDM1,INDM2) + IL(J)*YLMA(J,INDM1,IA)*CONJG(YLMA(J,INDM2,IB))*TMP
                ENDDO
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE FOURIERCOEFFS

SUBROUTINE FOURIERCOEFFSMML(COORDSB, COORDSA, NATOMS, L, KWIDTH, IMML, YMLB, YMLA)
!
! Calculates S03 Coefficients of the overlap integral of two structures
! does this calculation by direct calculation of the overlap between every pair
! of atoms, slower than the Harmonic basis, but slightly more accurate.
!

IMPLICIT NONE
DOUBLE PRECISION, INTENT(IN) :: COORDSA(3*NATOMS), COORDSB(3*NATOMS), KWIDTH
INTEGER, INTENT(IN) :: NATOMS, L
COMPLEX*16, INTENT(OUT) :: IMML(-L:L,-L:L,0:L)

COMPLEX*16, INTENT(OUT) ::  YMLA(-L:L,0:L,NATOMS), YMLB(-L:L,0:L,NATOMS)
!COMPLEX*16 YMLA(-L:L,0:L,NATOMS), YMLB(-L:L,0:L,NATOMS)
DOUBLE PRECISION RA(NATOMS), RB(NATOMS), IL(0:L), R1R2, EXPRA(NATOMS), EXPRB(NATOMS), FACT, TMP

INTEGER IA,IB,I,J,K,M1,M2,INDM1,INDM2

! Precalculate some values
DO I=1,NATOMS
    CALL RYML(COORDSA(3*I-2:3*I), RA(I), YMLA(:,:,I), L)
    CALL RYML(COORDSB(3*I-2:3*I), RB(I), YMLB(:,:,I), L)
    EXPRA(I) = EXP(-0.25D0 * RA(I)**2 / KWIDTH**2)
    EXPRB(I) = EXP(-0.25D0 * RB(I)**2 / KWIDTH**2)
ENDDO

FACT = 4.D0 * PI**2.5 * KWIDTH**3

IMML = CMPLX(0.D0,0.D0,8)
DO IA=1,NATOMS
    DO IB=1,NATOMS
        R1R2 = 0.5D0 * RA(IA)*RB(IB)/KWIDTH**2
        CALL SPHI(L, R1R2, K, IL)
        TMP = FACT*EXPRA(IA)*EXPRB(IB)
        DO J=0,L
            DO M2=-L,L
                DO M1=-L,L
!                    IMML(M1,M2,J) = IMML(M1,M2,J) + IL(J)*YMLA(M1,J,IA)*CONJG(YMLB(M2,J,IB))*TMP
                    IMML(M1,M2,J) = IMML(M1,M2,J) + IL(J)*YMLB(M1,J,IA)*CONJG(YMLA(M2,J,IB))*TMP
                ENDDO
            ENDDO
        ENDDO
    ENDDO
ENDDO

END SUBROUTINE FOURIERCOEFFSMML

SUBROUTINE CALCOVERLAP(IMML, OVERLAP, L, ILMM)
! Converts an array of SO(3) Fourier Coefficients to a discrete
! overlap array using a fast discrete SO(3) Fourier Transform (DSOFT)

USE DSOFT, ONLY : ISOFT

IMPLICIT NONE
INTEGER, INTENT(IN) :: L
COMPLEX*16, INTENT(IN) :: IMML(-L:L,-L:L,0:L)
DOUBLE PRECISION, INTENT(OUT) :: OVERLAP(2*L+2,2*L+2,2*L+2)

COMPLEX*16, INTENT(OUT) :: ILMM(0:L,0:2*L,0:2*L)
COMPLEX*16 FROT(2*L+2,2*L+2,2*L+2)
INTEGER I,J,M1,M2, NJ
INTEGER*8 BW

! Convert array into format usable by DSOFT:
BW = INT(L+1,8)
NJ = 2*L + 1

ILMM = CMPLX(0.D0, 0.D0, 8)
DO J=0,L
    ILMM(J,0,0) = IMML(0,0,J)
    DO M2=1,J
        ILMM(J,0,M2) = IMML(0,M2,J)
        ILMM(J,0,NJ-M2) = IMML(0,-M2,J)
        ILMM(J,M2,0) = IMML(M2,0,J)
        ILMM(J,NJ-M2,0) = IMML(-M2,0,J)
        DO M1=1,J
            ILMM(J,M1,M2) = IMML(M1,M2,J)
            ILMM(J,NJ-M1,M2) = IMML(-M1,M2,J)
            ILMM(J,M1,NJ-M2) = IMML(M1,-M2,J)
            ILMM(J,NJ-M1,NJ-M2) = IMML(-M1,-M2,J)
        ENDDO
    ENDDO
ENDDO

! Perform inverse discrete SO(3) Fourier Transform (DSOFT)
CALL ISOFT(ILMM, FROT, BW)
! Output is complex so must be converted back to real
OVERLAP = REAL(FROT, 8)

END SUBROUTINE CALCOVERLAP

SUBROUTINE FINDROTATIONS(OVERLAP, L, ANGLES, AMPLITUDES, NROTATIONS, DEBUG)
! Fits a set of Gaussians to the overlap integral and calculates the Euler angles these correspond to

USE FASTOVERLAPUTILS, ONLY: FINDPEAKS

IMPLICIT NONE

INTEGER, INTENT(IN) :: L
INTEGER, INTENT(INOUT) :: NROTATIONS
LOGICAL, INTENT(IN) :: DEBUG
DOUBLE PRECISION, INTENT(IN) :: OVERLAP(2*L+2,2*L+2,2*L+2)
DOUBLE PRECISION, INTENT(OUT) :: ANGLES(NROTATIONS,3), AMPLITUDES(NROTATIONS)!, ROTMS(3,3,NROTATIONS)

DOUBLE PRECISION CONVERT
INTEGER J

ANGLES=0.D0

CALL FINDPEAKS(OVERLAP, ANGLES, AMPLITUDES, NROTATIONS, DEBUG)

! Convert index locations to Euler Angles
CONVERT = PI / (2*L+2)
ANGLES(:,1) = (ANGLES(:,1)-1.0D0) * 2 * CONVERT
ANGLES(:,2) = (ANGLES(:,2)-0.5D0) * CONVERT
ANGLES(:,3) = (ANGLES(:,3)-1.0D0) * 2 * CONVERT

!WRITE(*,*) NROTATIONS
!WRITE(*,*) SHAPE(ANGLES), SHAPE(ROTMS(:,:,0)), SHAPE(ROTMS(:,:,NROTATIONS)) 
!!DO J=0,NROTATIONS
!!    CALL EULERM(ANGLES(J,1),ANGLES(J,2),ANGLES(J,3),ROTMS(:,:,J))
!!ENDDO

END SUBROUTINE FINDROTATIONS

SUBROUTINE EULERM(A,B,G,ROTM)
! Calculates rotation matrix of the Euler angles A,B,G
IMPLICIT NONE

DOUBLE PRECISION, INTENT(IN) :: A,B,G
DOUBLE PRECISION, INTENT(OUT) :: ROTM(3,3)

DOUBLE PRECISION  COSA, SINA, COSB, SINB, COSG, SING

COSA = COS(A)
SINA = SIN(A)
COSB = COS(B)
SINB = SIN(B)
COSG = COS(G)
SING = SIN(G)

!  !compute rotation matrix into geographical coordinates
!  ROTM (1,1) =   COSG * COSB * COSA  -  SING * SINA
!  ROTM (1,2) = - SING * COSB * COSA  -  COSG * SINA
!  ROTM (1,3) =          SINB * COSA
!  ROTM (2,1) =   COSG * COSB * SINA  +  SING * COSA
!  ROTM (2,2) = - SING * COSB * SINA  +  COSG * COSA
!  ROTM (2,3) =          SINB * SINA
!  ROTM (3,1) = - COSG * SINB
!  ROTM (3,2) =   SING * SINB
!  ROTM (3,3) =          COSB

  !compute rotation matrix into geographical coordinates
  ROTM (1,1) =   COSG * COSB * COSA  -  SING * SINA
  ROTM (2,1) =   SING * COSB * COSA  +  COSG * SINA
  ROTM (3,1) =          SINB * COSA
  ROTM (1,2) = - COSG * COSB * SINA  -  SING * COSA
  ROTM (2,2) = - SING * COSB * SINA  +  COSG * COSA
  ROTM (3,2) = -        SINB * SINA
  ROTM (1,3) = - COSG * SINB
  ROTM (2,3) = - SING * SINB
  ROTM (3,3) =          COSB

END SUBROUTINE EULERM

SUBROUTINE SETCLUSTER()

USE COMMONS, ONLY : MYUNIT,NFREEZE,GEOMDIFFTOL,ORBITTOL,FREEZE,PULLT,TWOD,  &
    &   EFIELDT,AMBERT,QCIAMBERT,AMBER12T,CHRMMT,STOCKT,CSMT,PERMDIST,      &
    &   LOCALPERMDIST,LPERMDIST,OHCELLT,QCIPERMCHECK,PERMOPT,PERMINVOPT,    &
    &   NOINVERSION,GTHOMSONT,MKTRAPT,MULLERBROWNT,RIGID, OHCELLT

IMPLICIT NONE

MYUNIT = 6
NFREEZE = 0
GEOMDIFFTOL = 0.5D0
ORBITTOL = 1.0D-3

FREEZE = .FALSE.
PULLT = .FALSE.
TWOD = .FALSE.
EFIELDT = .FALSE.
AMBERT = .FALSE.
QCIAMBERT = .FALSE.
AMBER12T = .FALSE.
CHRMMT = .FALSE.
STOCKT = .FALSE.
CSMT = .FALSE.
PERMDIST = .TRUE.
LOCALPERMDIST = .FALSE.
LPERMDIST = .FALSE.
OHCELLT = .FALSE.
QCIPERMCHECK = .FALSE.
PERMOPT = .TRUE.
PERMINVOPT = .TRUE.
NOINVERSION = .FALSE.
GTHOMSONT = .FALSE.
MKTRAPT = .FALSE.
MULLERBROWNT = .FALSE.
RIGID = .FALSE.
OHCELLT = .FALSE.

END SUBROUTINE SETCLUSTER

SUBROUTINE CHECKKEYWORDS()

USE COMMONS, ONLY : MYUNIT,NFREEZE,GEOMDIFFTOL,ORBITTOL,FREEZE,PULLT,TWOD,  &
    &   EFIELDT,AMBERT,QCIAMBERT,AMBER12T,CHRMMT,STOCKT,CSMT,PERMDIST,      &
    &   LOCALPERMDIST,LPERMDIST,OHCELLT,QCIPERMCHECK,PERMOPT,PERMINVOPT,    &
    &   NOINVERSION,GTHOMSONT,MKTRAPT,MULLERBROWNT,RIGID, OHCELLT

IMPLICIT NONE

IF(OHCELLT) THEN
    WRITE(*,'(A)') 'ERROR - cluster fastoverlap not compatible with OHCELL keyword'
    STOP
ENDIF

IF(STOCKT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with STOCK keyword'
    STOP
ENDIF

IF(CSMT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with CSM keyword'
    STOP
ENDIF

IF(PULLT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with PULL keyword'
    STOP
ENDIF

IF(EFIELDT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with EFIELD keyword'
    STOP
ENDIF

IF(RIGID) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with RIGID keyword'
    STOP
ENDIF

IF(QCIPERMCHECK) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with QCIPERMCHECK keyword'
    STOP
ENDIF

IF(QCIAMBERT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with QCIAMBER keyword'
    STOP
ENDIF

IF(GTHOMSONT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with GTHOMSON keyword'
    STOP
ENDIF

IF(MKTRAPT) THEN
    WRITE(*,'(A)') 'ERROR - fastoverlap not compatible with MKTRAP keyword'
    STOP
ENDIF

END SUBROUTINE CHECKKEYWORDS

SUBROUTINE ALIGN(COORDSB, COORDSA, NATOMS, DEBUG, L, KWIDTH, DISTANCE, DIST2, RMATBEST, NROTATIONS)

USE COMMONS, ONLY: BESTPERM, PERMOPT, PERMINVOPT, NOINVERSION, CHRMMT, AMBERT, AMBER12T
IMPLICIT NONE

INTEGER, INTENT(IN) :: NATOMS, L
INTEGER, INTENT(IN) :: NROTATIONS
LOGICAL, INTENT(IN) :: DEBUG
DOUBLE PRECISION, INTENT(IN) :: KWIDTH ! Gaussian Kernel width
DOUBLE PRECISION, INTENT(INOUT) :: COORDSA(3*NATOMS), COORDSB(3*NATOMS)
DOUBLE PRECISION, INTENT(OUT) :: DISTANCE, DIST2, RMATBEST(3,3)

COMPLEX*16 IMML(-L:L,-L:L,0:L), YMLA(-L:L,0:L,NATOMS), YMLB(-L:L,0:L,NATOMS)

DOUBLE PRECISION SAVEA(3*NATOMS),SAVEB(3*NATOMS)
DOUBLE PRECISION ANGLES(NROTATIONS,3), DISTSAVE, RMATSAVE(3,3), WORSTRAD, DIST2SAVE
INTEGER J, J1, NROT, INVERT
INTEGER SAVEPERM(NATOMS), KEEPPERM(NATOMS)

! Checking keywords are set properly
CALL CHECKKEYWORDS()

! Setting keywords for fastoverlap use of minpermdist, will be reset when exiting program
PERMINVOPTSAVE = PERMINVOPT
NOINVERSIONSAVE = NOINVERSION
PERMINVOPT = .FALSE.
NOINVERSION = .TRUE.

SAVEA(1:3*NATOMS) = COORDSA(1:3*NATOMS)
SAVEB(1:3*NATOMS) = COORDSB(1:3*NATOMS)

CALL FOURIERCOEFFSMML(SAVEB,SAVEA,NATOMS,L,KWIDTH,IMML,YMLB,YMLA)

NROT = NROTATIONS
CALL ALIGNCOEFFS(SAVEB,SAVEA,NATOMS,IMML,L,DEBUG,DISTSAVE,DIST2SAVE,RMATSAVE,NROT,ANGLES)

IF (PERMINVOPTSAVE.AND.(.NOT.(CHRMMT.OR.AMBERT.OR.AMBER12T))) THEN 
    IF (DEBUG) WRITE(MYUNIT,'(A)') 'fastoverlap> inverting geometry for comparison with target'
    ! Saving non inverted configuration
    XBESTASAVE(1:3*NATOMS) = SAVEA(1:3*NATOMS)
    KEEPPERM(1:NATOMS) = BESTPERM(1:NATOMS)
    SAVEA = -COORDSA(1:3*NATOMS)
    NROT = NROTATIONS
    CALL ALIGNCOEFFS(SAVEB,SAVEA,NATOMS,IMML,L,DEBUG,DISTANCE,DIST2,RMATBEST,NROT,ANGLES)
    IF (DISTANCE.LT.DISTSAVE) THEN
        IF (DEBUG) WRITE(MYUNIT,'(A,G20.10)') &
    &   'fastoverlap> inversion found better alignment, distance=', distance
        COORDSA(1:3*NATOMS) = SAVEA(1:3*NATOMS)
        RMATBEST = RMATSAVE
    ELSE
        COORDSA(1:3*NATOMS) = XBESTASAVE(1:3*NATOMS)
        DISTANCE = DISTSAVE
        DIST2 = DIST2SAVE
        RMATBEST = RMATSAVE
    ENDIF
ELSE
    IF (DEBUG) WRITE(MYUNIT,'(A)') 'fastoverlap> not inverting geometry for comparison with target'
    COORDSA(1:3*NATOMS) = SAVEA(1:3*NATOMS)
    DISTANCE = DISTSAVE
    DIST2 = DIST2SAVE
    RMATBEST = RMATSAVE
ENDIF

PERMINVOPT = PERMINVOPTSAVE
NOINVERSION = NOINVERSIONSAVE

END SUBROUTINE ALIGN

SUBROUTINE ALIGNCOEFFS(COORDSB,COORDSA,NATOMS,IMML,L,DEBUG,DISTANCE,DIST2,RMATBEST,NROTATIONS,ANGLES)
! Aligns two structures, specified by COORDSA and COORDSB, aligns COORDSA so it most
! closely matches COORDSB. 
! Assumes that COORDSA and COORDSB are both centered on their Centers of Mass
! Uses precalculated Fourier Coefficients, IMML

!USE COMMONS, ONLY : BESTPERM

IMPLICIT NONE

INTEGER, INTENT(IN) :: NATOMS, L
INTEGER, INTENT(IN) :: NROTATIONS
LOGICAL, INTENT(IN) :: DEBUG
DOUBLE PRECISION, INTENT(INOUT) :: COORDSA(3*NATOMS), COORDSB(3*NATOMS)
DOUBLE PRECISION, INTENT(OUT) :: ANGLES(NROTATIONS,3)
DOUBLE PRECISION, INTENT(OUT) :: DISTANCE, DIST2, RMATBEST(3,3)
COMPLEX*16, INTENT(IN) :: IMML(-L:L,-L:L,0:L)

COMPLEX*16 ILMM(0:L,0:2*L,0:2*L)
DOUBLE PRECISION OVERLAP(2*L+2,2*L+2,2*L+2)
DOUBLE PRECISION AMPLITUDES(NROTATIONS), BESTDIST, RMATSAVE(3,3), WORSTRAD
INTEGER J, J1, NROT
INTEGER SAVEPERM(NATOMS), KEEPPERM(NATOMS)


NROT = NROTATIONS
CALL CALCOVERLAP(IMML, OVERLAP, L, ILMM)
CALL FINDROTATIONS(OVERLAP, L, ANGLES, AMPLITUDES, NROT, DEBUG)

DO J1=1,NATOMS
    SAVEPERM(J1) = J1
    BESTPERM(J1) = J1
ENDDO

BESTDIST = HUGE(BESTDIST)
DUMMYB(:) = COORDSB(:3*NATOMS)

DO J=1,NROTATIONS
    IF (DEBUG) WRITE(MYUNIT,'(A,I3)') 'fastoverlap> testing rotation', J
    CALL EULERM(ANGLES(J,1),ANGLES(J,2),ANGLES(J,3),RMATSAVE)
    DO J1=1,NATOMS
        DUMMYA(J1*3-2:J1*3) = MATMUL(COORDSA(J1*3-2:J1*3), RMATSAVE)
    ENDDO

!    !Need to perform initial permutational alignment before running MINPERMDIST
!    CALL FINDBESTPERMUTATION(NATOMS,DUMMYB,DUMMYA,DEBUG,SAVEPERM,DISTANCE,DIST2,WORSTRAD)
!!    IF (DEBUG) WRITE(MYUNIT,'(A,G20.10)') 'fastoverlap> distance after intial permutation alignment=', DIST2
!    DO J1=1,NATOMS
!        DUMMYA(J1*3-2:J1*3) = COORDSA(SAVEPERM(J1)*3-2:SAVEPERM(J1)*3)
!    ENDDO

    CALL MINPERMDIST(DUMMYB,DUMMYA,NATOMS,DEBUG,0.D0,0.D0,0.D0,.FALSE.,.FALSE.,DISTANCE,DIST2,.FALSE.,RMATSAVE)
    IF (DEBUG) WRITE(MYUNIT,'(A,G20.10)') 'fastoverlap> minpermdist refined aligment distance found=', DISTANCE
    IF (DEBUG) WRITE(MYUNIT,'(A,G20.10)') 'fastoverlap> best aligment distance found=', BESTDIST

!    WRITE(*,*) J, DISTANCE, DIST2
    
    IF (DISTANCE.LT.BESTDIST) THEN
        BESTDIST = DISTANCE
        IF (DEBUG) WRITE(MYUNIT,'(A,G20.10)') 'fastoverlap> new best alignment found distance=', BESTDIST
!        DO J1=1,NATOMS
!            KEEPPERM(J1) = SAVEPERM(BESTPERM(J1))
!        ENDDO
        KEEPPERM = BESTPERM
        XBESTA(1:3*NATOMS) = DUMMYA(1:3*NATOMS)
        RMATBEST = RMATSAVE
    ENDIF
ENDDO

BESTPERM = KEEPPERM

! Returning Rotated Coordinates
COORDSA(1:3*NATOMS) = XBESTA(1:3*NATOMS)

! Returning Permuted Coordinates
DO J1=1,NATOMS
    J = BESTPERM(J1)
    COORDSA(J1*3-2:J1*3) = XBESTA(J*3-2:J*3)
ENDDO

DISTANCE = BESTDIST
DIST2 = BESTDIST**2

END SUBROUTINE ALIGNCOEFFS


SUBROUTINE FINDBESTPERMUTATION(NATOMS, COORDSB, COORDSA, DEBUG, SAVEPERM, LDISTANCE, DIST2, WORSTRAD)

! Find best permutational alignment of structures COORDSB with COORDSA given
! LDISTANCE returns the calculated
! distance^2 between the structures
USE COMMONS, ONLY : NSETS, SETS
IMPLICIT NONE

INTEGER, INTENT(IN) :: NATOMS
DOUBLE PRECISION, INTENT(IN) :: COORDSA(3*NATOMS), COORDSB(3*NATOMS)
LOGICAL, INTENT(IN) :: DEBUG
INTEGER, INTENT(OUT) :: SAVEPERM(NATOMS)
DOUBLE PRECISION, INTENT(OUT) :: LDISTANCE, DIST2, WORSTRAD

DOUBLE PRECISION PDUMMYA(3*NATOMS), PDUMMYB(3*NATOMS), DUMMYA(3*NATOMS), DUMMYB(3*NATOMS), CURRDIST
INTEGER NEWPERM(NATOMS), NDUMMY, J, J1, J2, J3, IND1, IND2
INTEGER PATOMS, LPERM(NATOMS)

NDUMMY=1
DO J1=1,NATOMS
    NEWPERM(J1)=J1
ENDDO

CURRDIST = 0.D0
DO J1=1,NPERMGROUP
    PATOMS=INT(NPERMSIZE(J1),4)
    DO J2=1,PATOMS
        IND2 = NEWPERM(PERMGROUP(NDUMMY+J2-1))
        PDUMMYA(3*J2-2:3*J2)=COORDSA(3*IND2-2:3*IND2)
        PDUMMYB(3*J2-2:3*J2)=COORDSB(3*IND2-2:3*IND2)
    ENDDO
    CALL MINPERM(PATOMS, PDUMMYB, PDUMMYA, 0.D0, 0.D0, 0.D0, .FALSE., LPERM, LDISTANCE, DIST2, WORSTRAD)
    CURRDIST = CURRDIST + LDISTANCE    
    SAVEPERM(1:NATOMS)=NEWPERM(1:NATOMS)
    DO J2=1,INT(PATOMS,4)
        SAVEPERM(PERMGROUP(NDUMMY+J2-1))=NEWPERM(PERMGROUP(NDUMMY+INT(LPERM(J2),4)-1))
    ENDDO

!    IF (NSETS(J1).GT.0) THEN
!        DO J2=1,PATOMS
!            DO J3=1,NSETS(J1)
!                SAVEPERM(SETS(PERMGROUP(NDUMMY+J2-1),J3))=SETS(NEWPERM(PERMGROUP(NDUMMY+LPERM(J2)-1)),J3)
!            ENDDO
!        ENDDO
!    ENDIF

    NDUMMY=NDUMMY+NPERMSIZE(J1)
    NEWPERM(1:NATOMS)=SAVEPERM(1:NATOMS)
ENDDO

!    CURRDIST = CURRDIST + LDISTANCE    
!    SAVEPERM(1:NATOMS)=NEWPERM(1:NATOMS)
!    DO J2=1,INT(PATOMS,4)
!        SAVEPERM(PERMGROUP(NDUMMY+J2-1))=NEWPERM(PERMGROUP(NDUMMY+INT(LPERM(J2),4)-1))
!    ENDDO
!    NDUMMY=NDUMMY+NPERMSIZE(J1)
!    NEWPERM(1:NATOMS)=SAVEPERM(1:NATOMS)
!ENDDO

LDISTANCE = CURRDIST
DIST2 = SQRT(LDISTANCE)

END SUBROUTINE FINDBESTPERMUTATION

END MODULE CLUSTERFASTOVERLAP

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

INCLUDE "bulkmindist.f90"
INCLUDE "minpermdist.f90"
INCLUDE "minperm.f90"
INCLUDE "newmindist.f90"
INCLUDE "orient.f90"
