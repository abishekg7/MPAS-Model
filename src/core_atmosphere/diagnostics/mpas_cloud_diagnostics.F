! Copyright (c) 2022, University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at https://mpas-dev.github.io/license.html
!

#ifdef MPAS_OPENACC
#define MPAS_ACC_TIMER_START(X) call mpas_timer_start(X)
#define MPAS_ACC_TIMER_STOP(X) call mpas_timer_stop(X)
#else
#define MPAS_ACC_TIMER_START(X)
#define MPAS_ACC_TIMER_STOP(X)
#endif

module mpas_cloud_diagnostics

    use mpas_derived_types, only : MPAS_pool_type, MPAS_clock_type
    use mpas_kind_types, only : RKIND

    type (MPAS_pool_type), pointer :: mesh
    type (MPAS_pool_type), pointer :: diag
    type (MPAS_pool_type), pointer :: diag_physics

    type (MPAS_clock_type), pointer :: clock

    private

    public :: cloud_diagnostics_setup, &
              cloud_diagnostics_pre_compute, &
              cloud_diagnostics_compute


    contains


    !-----------------------------------------------------------------------
    !  routine cloud_diagnostics_setup
    !
    !> \brief Initialize the cloud diagnostic module
    !> \author G. Dylan Dickerson
    !> \date   23 August 2022
    !> \details
    !>  Initialize the diagnostic and save pointers to subpools for
    !>  reuse in this module
    !
    !-----------------------------------------------------------------------
    subroutine cloud_diagnostics_setup(all_pools, simulation_clock)

        use mpas_derived_types, only : MPAS_pool_type, MPAS_clock_type
        use mpas_pool_routines, only : mpas_pool_get_subpool

        implicit none

        type (MPAS_pool_type), pointer :: all_pools
        type (MPAS_clock_type), pointer :: simulation_clock


        call mpas_pool_get_subpool(all_pools, 'mesh', mesh)
        call mpas_pool_get_subpool(all_pools, 'diag', diag)
        call mpas_pool_get_subpool(all_pools, 'diag_physics', diag_physics)

        clock => simulation_clock

    end subroutine cloud_diagnostics_setup


    !-----------------------------------------------------------------------
    !  routine cloud_diagnostics_pre_compute
    !
    !> \brief Copies device-resident fields to the host for cloud_diagnostics_compute
    !> \details
    !>  When dynamics fields are resident on the GPU, the host copies of
    !>  the pressure fields read by cloud_diagnostics_compute are stale.
    !>  This routine updates them on the host when any of the UPP cloud
    !>  fraction fields will be written. It does nothing in non-OpenACC builds.
    !
    !-----------------------------------------------------------------------
    subroutine cloud_diagnostics_pre_compute()

#ifdef MPAS_OPENACC
        use mpas_atm_diagnostics_utils, only : MPAS_field_will_be_written
        use mpas_pool_routines, only : mpas_pool_get_array
        use mpas_timer, only : mpas_timer_start, mpas_timer_stop
#endif

        implicit none


#ifdef MPAS_OPENACC
        real (kind=RKIND), dimension(:,:), pointer :: pressure_base, pressure_p

        if (MPAS_field_will_be_written('cldfrac_low_UPP') .or. &
            MPAS_field_will_be_written('cldfrac_mid_UPP') .or. &
            MPAS_field_will_be_written('cldfrac_high_UPP') .or. &
            MPAS_field_will_be_written('cldfrac_tot_UPP')) then
            MPAS_ACC_TIMER_START('cloud_diagnostics_compute [ACC_data_xfer]')
            call mpas_pool_get_array(diag, 'pressure_base', pressure_base)
            !$acc update host(pressure_base)
            call mpas_pool_get_array(diag, 'pressure_p', pressure_p)
            !$acc update host(pressure_p)
            MPAS_ACC_TIMER_STOP('cloud_diagnostics_compute [ACC_data_xfer]')
        end if
#endif

    end subroutine cloud_diagnostics_pre_compute


    !-----------------------------------------------------------------------
    !  routine cloud_diagnostics_compute
    !
    !> \brief Compute diagnostic before model output is written
    !> \author G. Dylan Dickerson
    !> \date   23 August 2022
    !> \details
    !>  Compute diagnostic before model output is written
    !>  The following fields are computed by this routine:
    !>     cldfrac_low_UPP
    !>     cldfrac_mid_UPP
    !>     cldfrac_high_UPP
    !>     cldfrac_tot_UPP
    !
    !-----------------------------------------------------------------------
    subroutine cloud_diagnostics_compute()

        use mpas_atm_diagnostics_utils, only : MPAS_field_will_be_written
        use mpas_pool_routines, only : mpas_pool_get_dimension, mpas_pool_get_array

        implicit none

        integer :: iCell, k
        integer, pointer :: nCellsSolve, nVertLevels

        real (kind=RKIND), dimension(:), pointer :: cldfrac_low_UPP
        real (kind=RKIND), dimension(:), pointer :: cldfrac_mid_UPP
        real (kind=RKIND), dimension(:), pointer :: cldfrac_high_UPP
        real (kind=RKIND), dimension(:), pointer :: cldfrac_tot_UPP

        real (kind=RKIND), dimension(:), allocatable :: p_in
        real (kind=RKIND), dimension(:,:), pointer :: pressure_p
        real (kind=RKIND), dimension(:,:), pointer :: pressure_base
        real (kind=RKIND), dimension(:,:), pointer :: cldfrac

        ! levels for low/mid/high cloud fraction - UPP method
        real (kind=RKIND), parameter :: ptop_low = 64200.0, ptop_mid = 35000.0, ptop_high = 15000.0

        logical :: need_cldfrac_UPP


        need_cldfrac_UPP = MPAS_field_will_be_written('cldfrac_low_UPP')
        need_cldfrac_UPP = MPAS_field_will_be_written('cldfrac_mid_UPP')  .or. need_cldfrac_UPP
        need_cldfrac_UPP = MPAS_field_will_be_written('cldfrac_high_UPP') .or. need_cldfrac_UPP
        need_cldfrac_UPP = MPAS_field_will_be_written('cldfrac_tot_UPP')  .or. need_cldfrac_UPP

        if (need_cldfrac_UPP) then
           call mpas_pool_get_dimension(mesh, 'nCellsSolve', nCellsSolve)
           call mpas_pool_get_dimension(mesh, 'nVertLevels', nVertLevels)

           call mpas_pool_get_array(diag, 'cldfrac_low_UPP',  cldfrac_low_UPP)
           call mpas_pool_get_array(diag, 'cldfrac_mid_UPP',  cldfrac_mid_UPP)
           call mpas_pool_get_array(diag, 'cldfrac_high_UPP', cldfrac_high_UPP)
           call mpas_pool_get_array(diag, 'cldfrac_tot_UPP',  cldfrac_tot_UPP)

           call mpas_pool_get_array(diag, 'pressure_base', pressure_base)
           call mpas_pool_get_array(diag, 'pressure_p', pressure_p)
           call mpas_pool_get_array(diag_physics, 'cldfrac', cldfrac)

           allocate(p_in(nVertLevels))

           do iCell = 1, nCellsSolve
               cldfrac_low_UPP (iCell) = 0.0
               cldfrac_mid_UPP (iCell) = 0.0
               cldfrac_high_UPP(iCell) = 0.0
               cldfrac_tot_UPP (iCell) = 0.0
               p_in(1:nVertLevels) = pressure_p(1:nVertLevels,iCell) + pressure_base(1:nVertLevels,iCell)
               do k = 1, nVertLevels
                  if ( p_in(k) >= ptop_low ) then
                      cldfrac_low_UPP(iCell)  = max(cldfrac_low_UPP(iCell), cldfrac(k,iCell))
                  else if ( p_in(k) < ptop_low .and. p_in(k) >= ptop_mid  ) then
                      cldfrac_mid_UPP(iCell)  = max(cldfrac_mid_UPP(iCell), cldfrac(k,iCell))
                  else if ( p_in(k) < ptop_mid .and. p_in(k) >= ptop_high ) then
                      cldfrac_high_UPP(iCell) = max(cldfrac_high_UPP(iCell), cldfrac(k,iCell))
                  end if
                  cldfrac_tot_UPP(iCell) = max(cldfrac_tot_UPP(iCell), cldfrac(k,iCell))
               end do
           end do

           deallocate(p_in)

        end if ! need_cldfrac_UPP

    end subroutine cloud_diagnostics_compute

end module mpas_cloud_diagnostics
