      SUBROUTINE mod_arrays (allocate_vars)
!
!svn $Id: mod_arrays.F 795 2016-05-11 01:42:43Z arango $
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.txt                                              !
!=======================================================================
!                                                                      !
!  This routine routine allocates and initializa model state arrays    !
!  for each nested and/or multiple connected grids.                    !
!                                                                      !
!=======================================================================
!
      USE mod_param
      USE mod_parallel
      USE mod_scalars
!
      USE mod_boundary, ONLY : allocate_boundary, initialize_boundary
      USE mod_clima, ONLY : allocate_clima, initialize_clima
      USE mod_coupling, ONLY : allocate_coupling, initialize_coupling
      USE mod_diags, ONLY : allocate_diags, initialize_diags
      USE mod_forces, ONLY : allocate_forces, initialize_forces
      USE mod_grid, ONLY : allocate_grid, initialize_grid
      USE mod_mixing, ONLY : allocate_mixing, initialize_mixing
      USE mod_ocean, ONLY : allocate_ocean, initialize_ocean
      USE mod_sedbed, ONLY : allocate_sedbed, initialize_sedbed
      USE mod_vegarr,ONLY:allocate_vegarr, initialize_vegarr
      USE mod_sources, ONLY : allocate_sources
      USE mod_bbl, ONLY : allocate_bbl, initialize_bbl
!
      implicit none
!
!  Imported variable declarations
!
      logical, intent(in) :: allocate_vars
!
!  Local variable declarations.
!
      logical :: LallocateClima
      integer :: ng, thread, tile
      integer :: LBi, UBi, LBj, UBj, LBij, UBij
      integer, parameter :: model = 0
!
!-----------------------------------------------------------------------
!  Turn on allocation time wall clock.
!-----------------------------------------------------------------------
!
        DO ng=1,Ngrids
          DO thread=MyRank,MyRank
            CALL wclock_on (ng, iNLM, 1)
          END DO
!$OMP BARRIER
        END DO
!
!-----------------------------------------------------------------------
!  Allocate model structures.
!-----------------------------------------------------------------------
!
      IF (allocate_vars) then
        tile=MyRank
        LallocateClima=.FALSE.
        DO ng=1,Ngrids
!$OMP MASTER
          LBi=BOUNDS(ng)%LBi(tile)
          UBi=BOUNDS(ng)%UBi(tile)
          LBj=BOUNDS(ng)%LBj(tile)
          UBj=BOUNDS(ng)%UBj(tile)
          LBij=BOUNDS(ng)%LBij
          UBij=BOUNDS(ng)%UBij
          CALL allocate_boundary (ng)
          CALL allocate_bbl (ng, LBi, UBi, LBj, UBj)
          IF (LallocateClima.or.Lclimatology(ng)) THEN
            CALL allocate_clima (ng, LBi, UBi, LBj, UBj)
          END IF
          CALL allocate_coupling (ng, LBi, UBi, LBj, UBj)
          CALL allocate_diags (ng, LBi, UBi, LBj, UBj)
          CALL allocate_forces (ng, LBi, UBi, LBj, UBj)
          CALL allocate_grid (ng, LBi, UBi, LBj, UBj, LBij, UBij)
          CALL allocate_mixing (ng, LBi, UBi, LBj, UBj)
          CALL allocate_ocean (ng, LBi, UBi, LBj, UBj)
          CALL allocate_sedbed (ng, LBi, UBi, LBj, UBj)
          CALL allocate_vegarr(ng, LBi, UBi, LBj, UBj)
          IF (LuvSrc(ng).or.LwSrc(ng).or.ANY(LtracerSrc(:,ng))) THEN
            CALL allocate_sources (ng)
          END IF
!$OMP END MASTER
!$OMP BARRIER
        END DO
      END IF
!
!-----------------------------------------------------------------------
!  Intialize variables within structures for each grid.
!-----------------------------------------------------------------------
!
      DO ng=1,Ngrids
        DO tile=first_tile(ng),last_tile(ng),+1
          CALL initialize_bbl (ng, tile)
          CALL initialize_boundary (ng, tile, model)
          IF (LallocateClima.or.Lclimatology(ng)) THEN
            CALL initialize_clima (ng, tile)
          END IF
          CALL initialize_coupling (ng, tile, model)
          CALL initialize_diags (ng, tile)
          CALL initialize_forces (ng, tile, model)
          CALL initialize_grid (ng, tile, model)
          CALL initialize_mixing (ng, tile, model)
          CALL initialize_ocean (ng, tile, model)
          CALL initialize_sedbed (ng, tile, model)
            CALL initialize_vegarr (ng, TILE, model)
        END DO
!$OMP BARRIER
      END DO
!
!-----------------------------------------------------------------------
!  Turn off allocation time wall clock.
!-----------------------------------------------------------------------
!
      DO ng=1,Ngrids
        DO thread=MyRank,MyRank
          CALL wclock_off (ng, iNLM, 1)
        END DO
!$OMP BARRIER
      END DO
      RETURN
      END SUBROUTINE mod_arrays
