! Copyright (c) 2016,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!

#ifdef MPAS_OPENACC
#define MPAS_ACC_TIMER_START(X) call mpas_timer_start(X)
#define MPAS_ACC_TIMER_STOP(X) call mpas_timer_stop(X)
#else
#define MPAS_ACC_TIMER_START(X)
#define MPAS_ACC_TIMER_STOP(X)
#endif

module mpas_atm_diagnostics_utils

    use mpas_derived_types, only : MPAS_streamManager_type, MPAS_pool_type

    private

    public :: mpas_atm_diag_utils_init, &
              mpas_atm_diag_utils_finalize, &
              mpas_field_will_be_written, &
              mpas_stream_inclusion_count, &
              mpas_atm_diag_update_host, &
              mpas_atm_diag_reset_host_flags


    type (MPAS_streamManager_type), pointer :: streamManager

    !
    ! Hash table (an MPAS pool of integer config entries) mapping the name of a
    ! GPU-resident field to the value of hostSyncEpoch at which it was last
    ! copied to the host by mpas_atm_diag_update_host. Entries are added on the
    ! first request for a field. A field is current on the host if its entry
    ! equals hostSyncEpoch; mpas_atm_diag_reset_host_flags advances the epoch,
    ! which marks every field stale without visiting the table.
    !
    type (MPAS_pool_type), pointer :: hostSyncTable => null()
    integer :: hostSyncEpoch = 1

    contains


    !-----------------------------------------------------------------------
    !  routine MPAS_atm_diag_utils_init
    !
    !> \brief Prepares diagnostics utilities for use by diagnostics modules
    !> \author Michael Duda
    !> \date   12 October 2016
    !> \details
    !>  This routine prepares the diagnostics utilities for use by diagnostics
    !>  modules.
    !
    !-----------------------------------------------------------------------
    subroutine mpas_atm_diag_utils_init(stream_mgr)

        use mpas_derived_types, only : MPAS_streamManager_type
        use mpas_pool_routines, only : mpas_pool_create_pool

        implicit none

        type (MPAS_streamManager_type), target, intent(inout) :: stream_mgr

        streamManager => stream_mgr

        call mpas_pool_create_pool(hostSyncTable)
        hostSyncEpoch = 1

    end subroutine mpas_atm_diag_utils_init


    !-----------------------------------------------------------------------
    !  routine MPAS_atm_diag_utils_finalize
    !
    !> \brief Performs cleanup after diagnostics utilities will no longer be used
    !> \author Michael Duda
    !> \date   12 October 2016
    !> \details
    !>  This routine performs cleanup after diagnostics utilities will no 
    !>  longer be used
    !
    !-----------------------------------------------------------------------
    subroutine mpas_atm_diag_utils_finalize()

        use mpas_pool_routines, only : mpas_pool_destroy_pool

        implicit none

        if (associated(hostSyncTable)) then
            call mpas_pool_destroy_pool(hostSyncTable)
            nullify(hostSyncTable)
        end if

    end subroutine mpas_atm_diag_utils_finalize


    !-----------------------------------------------------------------------
    !  routine mpas_atm_diag_update_host
    !
    !> \brief Copies a shared device-resident field to the host once per time step
    !> \details
    !>  Several diagnostics read the same GPU-resident dynamics fields on the
    !>  host. This routine performs the '!$acc update host' for the named field
    !>  only if it has not already been done since the last call to
    !>  mpas_atm_diag_reset_host_flags, as recorded in hostSyncTable. pool is
    !>  the pool holding the field ('state' or 'diag'); fields with multiple
    !>  time levels are always taken at time level 1. Any 1-, 2- or 3-d real
    !>  field may be requested; the field name is used as the table key, so it
    !>  must not refer to different fields in different pools. In non-OpenACC
    !>  builds only the table is updated.
    !
    !-----------------------------------------------------------------------
    subroutine mpas_atm_diag_update_host(fieldName, pool)

        use mpas_derived_types, only : MPAS_pool_type, MPAS_POOL_SILENT, MPAS_LOG_CRIT
        use mpas_pool_routines, only : mpas_pool_add_config, mpas_pool_get_config, &
                                       mpas_pool_get_error_level, mpas_pool_set_error_level
#ifdef MPAS_OPENACC
        use mpas_derived_types, only : MPAS_pool_field_info_type, MPAS_POOL_REAL
        use mpas_kind_types, only : RKIND
        use mpas_pool_routines, only : mpas_pool_get_array, mpas_pool_get_field_info
        use mpas_timer, only : mpas_timer_start, mpas_timer_stop
#endif
        use mpas_log, only : mpas_log_write

        implicit none

        character(len=*), intent(in) :: fieldName
        type (MPAS_pool_type), intent(in) :: pool

        integer, pointer :: lastCopiedEpoch
        integer :: err_level
#ifdef MPAS_OPENACC
        type (MPAS_pool_field_info_type) :: info
        real (kind=RKIND), dimension(:), pointer :: array1d
        real (kind=RKIND), dimension(:,:), pointer :: array2d
        real (kind=RKIND), dimension(:,:,:), pointer :: array3d
#endif

        if (.not. associated(hostSyncTable)) then
            call mpas_log_write('mpas_atm_diag_update_host: called before mpas_atm_diag_utils_init', messageType=MPAS_LOG_CRIT)
        end if

        ! Look up the field; a missing key is expected on first use, so silence the pool error
        err_level = mpas_pool_get_error_level()
        call mpas_pool_set_error_level(MPAS_POOL_SILENT)
        call mpas_pool_get_config(hostSyncTable, trim(fieldName), lastCopiedEpoch)
        call mpas_pool_set_error_level(err_level)

        if (associated(lastCopiedEpoch)) then
            if (lastCopiedEpoch == hostSyncEpoch) return
        else
            call mpas_pool_add_config(hostSyncTable, trim(fieldName), 0)
            call mpas_pool_get_config(hostSyncTable, trim(fieldName), lastCopiedEpoch)
        end if

#ifdef MPAS_OPENACC
        call mpas_pool_get_field_info(pool, trim(fieldName), info)
        if (info % fieldType /= MPAS_POOL_REAL) then
            call mpas_log_write('mpas_atm_diag_update_host: '//trim(fieldName)//' is not a real field in the given pool', &
                                messageType=MPAS_LOG_CRIT)
        end if

        MPAS_ACC_TIMER_START('diagnostics [ACC_data_xfer]')
        select case (info % nDims)
        case (1)
            if (info % nTimeLevels > 1) then
                call mpas_pool_get_array(pool, trim(fieldName), array1d, 1)
            else
                call mpas_pool_get_array(pool, trim(fieldName), array1d)
            end if
            !$acc update host(array1d)
        case (2)
            if (info % nTimeLevels > 1) then
                call mpas_pool_get_array(pool, trim(fieldName), array2d, 1)
            else
                call mpas_pool_get_array(pool, trim(fieldName), array2d)
            end if
            !$acc update host(array2d)
        case (3)
            if (info % nTimeLevels > 1) then
                call mpas_pool_get_array(pool, trim(fieldName), array3d, 1)
            else
                call mpas_pool_get_array(pool, trim(fieldName), array3d)
            end if
            !$acc update host(array3d)
        case default
            call mpas_log_write('mpas_atm_diag_update_host: unsupported dimensionality for '//trim(fieldName), &
                                messageType=MPAS_LOG_CRIT)
        end select
        MPAS_ACC_TIMER_STOP('diagnostics [ACC_data_xfer]')
#endif

        lastCopiedEpoch = hostSyncEpoch

    end subroutine mpas_atm_diag_update_host


    !-----------------------------------------------------------------------
    !  routine mpas_atm_diag_reset_host_flags
    !
    !> \brief Marks all shared fields as stale on the host
    !> \details
    !>  Must be called after any device computation that changes the fields
    !>  tracked in hostSyncTable (i.e., after each dynamics time step), so that
    !>  the next mpas_atm_diag_update_host call copies them again. Advancing
    !>  the epoch invalidates every table entry at once.
    !
    !-----------------------------------------------------------------------
    subroutine mpas_atm_diag_reset_host_flags()

        implicit none

        hostSyncEpoch = hostSyncEpoch + 1

    end subroutine mpas_atm_diag_reset_host_flags


    !-----------------------------------------------------------------------
    !  routine MPAS_field_will_be_written
    !
    !> \brief Decide if a field will be written in next call to mpas_stream_mgr_write
    !> \author Michael Duda
    !> \date   12 October 2016
    !> \details
    !>  This function queries the stream manager to see whether there are any
    !>  streams that contain the field 'fieldName' and whose output alarms
    !>  are also ringing. If so, the function returns .true..
    !>  The assumption is that, between the call to this function and the next
    !>  call to write all streams with mpas_stream_mgr_write(), the stream
    !>  (or streams) containing the named field will not have their alarms
    !>  externally reset.
    !
    !-----------------------------------------------------------------------
    logical function mpas_field_will_be_written(fieldName)

        use mpas_kind_types, only : StrKIND
        use mpas_derived_types, only : MPAS_STREAM_OUTPUT, MPAS_STREAM_INPUT_OUTPUT
        use mpas_stream_manager, only : mpas_stream_mgr_begin_iteration, mpas_stream_mgr_get_next_stream, &
                                        MPAS_stream_mgr_ringing_alarms, mpas_stream_mgr_get_next_field

        implicit none

        character(len=*), intent(in) :: fieldName

        character (len=StrKIND) :: streamNameItr
        character (len=StrKIND) :: fieldNameItr
        integer :: streamDirection
        logical :: streamActive
        logical :: fieldActive
        integer :: ierr

        mpas_field_will_be_written = .false.

        call mpas_stream_mgr_begin_iteration(streamManager)
        do while (mpas_stream_mgr_get_next_stream(streamManager, streamID = streamNameItr, &
                                                  directionProperty = streamDirection, activeProperty = streamActive))

            if (streamActive .and. ( streamDirection == MPAS_STREAM_OUTPUT .or. streamDirection == MPAS_STREAM_INPUT_OUTPUT )) then

                if (MPAS_stream_mgr_ringing_alarms(streamManager, streamID=streamNameItr, &
                                                   direction=MPAS_STREAM_OUTPUT, ierr=ierr)) then

                    call mpas_stream_mgr_begin_iteration(streamManager, streamID=streamNameItr)
                    do while (mpas_stream_mgr_get_next_field(streamManager, streamNameItr, fieldNameItr, isActive=fieldActive))

                        if (fieldActive .and. (fieldNameItr == fieldName)) then
                            mpas_field_will_be_written = .true.
                            return
                        end if

                    end do
                end if

            end if

        end do

    end function mpas_field_will_be_written


    !-----------------------------------------------------------------------
    !  routine MPAS_stream_inclusion_count
    !
    !> \brief Returns the number of streams containing the specified field
    !> \author Michael Duda
    !> \date   18 October 2016
    !> \details
    !>  This function queries the stream manager to determine how many streams
    !>  contain the specified field. The optional argument 'direction' can be
    !>  used to limit the count to only input streams, only output streams, or
    !>  both input and output streams. By default, the function only counts
    !>  streams that have a non-'none' input/output interval, but even streams
    !>  with input_interval or output_interval equal to 'none' can be considered
    !>  by setting the optional argument 'includeInactive' to .true..
    !
    !-----------------------------------------------------------------------
    integer function mpas_stream_inclusion_count(fieldName, direction, includeInactive)

        use mpas_kind_types, only : StrKIND
        use mpas_derived_types, only : MPAS_STREAM_INPUT, MPAS_STREAM_OUTPUT, MPAS_STREAM_INPUT_OUTPUT, &
                                       MPAS_STREAM_PROPERTY_RECORD_INTV
        use mpas_stream_manager, only : mpas_stream_mgr_begin_iteration, mpas_stream_mgr_get_next_stream, &
                                        MPAS_stream_mgr_ringing_alarms, mpas_stream_mgr_get_next_field, &
                                        mpas_stream_mgr_get_property

        implicit none

        character(len=*), intent(in) :: fieldName
        integer, intent(in), optional :: direction
        logical, intent(in), optional :: includeInactive

        character (len=StrKIND) :: streamNameItr
        character (len=StrKIND) :: fieldNameItr
        character (len=StrKIND) :: recordIntervalIn
        character (len=StrKIND) :: recordIntervalOut
        integer :: streamDirection
        logical :: streamActive
        logical :: fieldActive
        integer :: ierr

        integer :: local_direction
        logical :: local_includeInactive


        if (present(direction)) then
            local_direction = direction
        else
            local_direction = MPAS_STREAM_INPUT_OUTPUT
        end if

        if (present(includeInactive)) then
            local_includeInactive = includeInactive
        else
            local_includeInactive = .false.
        end if


        mpas_stream_inclusion_count = 0

        call mpas_stream_mgr_begin_iteration(streamManager)
        STREAM_LOOP: do while (mpas_stream_mgr_get_next_stream(streamManager, streamID = streamNameItr, &
                                                               directionProperty = streamDirection, activeProperty = streamActive))

            call MPAS_stream_mgr_get_property(streamManager, trim(streamNameItr), MPAS_STREAM_PROPERTY_RECORD_INTV, &
                                              recordIntervalIn, direction=MPAS_STREAM_INPUT, ierr=ierr)

            call MPAS_stream_mgr_get_property(streamManager, trim(streamNameItr), MPAS_STREAM_PROPERTY_RECORD_INTV, &
                                              recordIntervalOut, direction=MPAS_STREAM_OUTPUT, ierr=ierr)

            ! Determine whether this stream is "active" for the purposes of consideration here
            if (.not. local_includeInactive) then 
                if (streamActive) then
                    streamActive = ((local_direction == MPAS_STREAM_INPUT .and. trim(recordIntervalIn) /= 'none') &
                                    .or. (local_direction == MPAS_STREAM_OUTPUT .and. trim(recordIntervalOut) /= 'none') &
                                    .or. (local_direction == MPAS_STREAM_INPUT_OUTPUT .and. ((trim(recordIntervalIn) /= 'none') &
                                                                                             .or. (trim(recordIntervalOut) /= 'none'))))
                end if
            else
                streamActive = .true.
            end if

            if (streamActive .and. ((local_direction == MPAS_STREAM_INPUT .and. streamDirection == MPAS_STREAM_INPUT) &
                                    .or. (local_direction == MPAS_STREAM_OUTPUT .and. streamDirection == MPAS_STREAM_OUTPUT) &
                                    .or. (local_direction == MPAS_STREAM_INPUT_OUTPUT) &
                                    .or. (streamDirection == MPAS_STREAM_INPUT_OUTPUT))) then

                call mpas_stream_mgr_begin_iteration(streamManager, streamID=streamNameItr)
                do while (mpas_stream_mgr_get_next_field(streamManager, streamNameItr, fieldNameItr, isActive=fieldActive))

                    if (fieldActive .and. (fieldNameItr == fieldName)) then
                        mpas_stream_inclusion_count = mpas_stream_inclusion_count + 1
                        cycle STREAM_LOOP
                    end if

                end do

            end if

        end do STREAM_LOOP

    end function mpas_stream_inclusion_count


end module mpas_atm_diagnostics_utils
