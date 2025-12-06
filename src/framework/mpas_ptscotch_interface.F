#ifdef MPAS_SCOTCH
module mpas_ptscotch_interface
    use iso_c_binding, only : c_int, c_double
#include "ptscotchf.h"
    public :: scotch_dgraphinit, scotch_dgraphbuild

    

contains

    function scotch_dgraphinit(dgraph, comm) result(ierr)
        use iso_c_binding, only : c_ptr, c_loc
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT

        implicit none
        ! Arguments
        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer, intent(in) :: comm

        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphinit(dgraph_ptr, localcomm) bind(C, name='scotchm_dgraphinit') result(err)
                use iso_c_binding, only : c_ptr, c_int
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: localcomm
                integer(c_int) :: err
            end function scotchfdgraphinit
        end interface

        ierr = scotchfdgraphinit(c_loc(dgraph), comm)

        if (ierr /= 0) then
            call mpas_log_write('Error initalizing distributed Scotch graph')
        else 
            call mpas_log_write('Successfully initialized distributed Scotch graph')    
        end if

    end function scotch_dgraphinit


    function scotch_dgraphbuild(dgraph, nVertices, vertloctab, nLocEdgesGraph, edgelocsiz, adjncy) result(ierr)

        use iso_c_binding, only : c_ptr, c_loc
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: nVertices
        integer(SCOTCH_NUMSIZE), intent(in) :: vertloctab(nVertices+1)
        integer(SCOTCH_NUMSIZE), intent(in) :: nLocEdgesGraph
        integer(SCOTCH_NUMSIZE), intent(in) :: edgelocsiz
        integer(SCOTCH_NUMSIZE), intent(in) :: adjncy(nLocEdgesGraph)



        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphbuild(dgraph_ptr, nVertices, vertloctab, &
                nLocEdgesGraph, edgelocsiz, adjncy) bind(C, name='scotchm_dgraphbuild') result(err)
                use iso_c_binding, only : c_ptr, c_int
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: nVertices
                integer(c_int) :: vertloctab(nVertices+1)
                integer(c_int), value :: nLocEdgesGraph
                integer(c_int), value :: edgelocsiz
                integer(c_int) :: adjncy(nLocEdgesGraph)
                integer(c_int) :: err
            end function scotchfdgraphbuild
        end interface


        ierr = 0

        ierr = scotchfdgraphbuild(c_loc(dgraph), nVertices, vertloctab,  &   
                                  nLocEdgesGraph, edgelocsiz, adjncy)

        if (ierr /= 0) then
            call mpas_log_write('Error building distributed Scotch graph', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully built distributed Scotch graph')    
        end if


    end function scotch_dgraphbuild

    function scotch_dgraphcheck(dgraph) result(ierr)

        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphcheck(dgraph_ptr) bind(C, name='scotchm_dgraphcheck') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: err
            end function scotchfdgraphcheck
        end interface

        ierr = scotchfdgraphcheck(c_loc(dgraph))

        if (ierr /= 0) then
            call mpas_log_write('Error during distributed Scotch graph check', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully checked distributed Scotch graph')    
        end if


    end function scotch_dgraphcheck


     subroutine scotch_dgraphexit(dgraph)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        interface
            subroutine scotchfdgraphexit(dgraph_ptr) bind(C, name='scotchm_dgraphexit')
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
            end subroutine scotchfdgraphexit
        end interface

        call scotchfdgraphexit(c_loc(dgraph))

    end subroutine scotch_dgraphexit


    function scotch_stratinit(stradat) result(ierr)

        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        
        ! Return value
        integer :: ierr

        interface
            function scotchfstratinit(strat_ptr) bind(C, name='scotchm_stratinit') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: strat_ptr
                integer(c_int) :: err
            end function scotchfstratinit
        end interface

        ierr = scotchfstratinit(c_loc(stradat))

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch strategy initialization', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully initialized Scotch strategy')
        end if

    end function scotch_stratinit

    subroutine scotch_stratexit(stradat)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        
        interface
            subroutine scotchfstratexit(strat_ptr) bind(C, name='scotchm_stratexit')
                use iso_c_binding, only : c_ptr
                type(c_ptr), value :: strat_ptr
            end subroutine scotchfstratexit
        end interface

        call scotchfstratexit(c_loc(stradat))

    end subroutine scotch_stratexit

    
    function scotch_dgraphpart(dgraph, num_part, stradat, parttab) result(ierr)

        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: num_part
        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        integer(SCOTCH_NUMSIZE), intent(out) :: parttab(*)
        
        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphpart(dgraph_ptr, num_part_loc, strat_ptr, parttab_loc ) bind(C, name='scotchm_dgraphpart') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: num_part_loc
                type(c_ptr), value :: strat_ptr
                integer(c_int) :: parttab_loc(*)
                integer(c_int) :: err
            end function scotchfdgraphpart
        end interface

        ierr = scotchfdgraphpart(c_loc(dgraph), num_part, c_loc(stradat), parttab)

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch graph partition', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully partitioned distributed Scotch graph')
        end if

    end function scotch_dgraphpart


    function scotch_dgraphredist(dgraph, parttab, dgraph_out, num_local_vertices) result(ierr)

        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: parttab(*)
        doubleprecision, target, intent(inout) :: dgraph_out (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE) :: num_local_vertices
           
        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphredist(dgraph_ptr, parttab_loc, dgraph_out_ptr, vertlocnbr ) bind(C, name='scotchm_dgraphredist') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: parttab_loc(*)
                type(c_ptr), value :: dgraph_out_ptr
                integer(c_int) :: vertlocnbr
                integer(c_int) :: err
            end function scotchfdgraphredist
        end interface

        ierr = scotchfdgraphredist(c_loc(dgraph), parttab, c_loc(dgraph_out), num_local_vertices)

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch graph redistribution', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully redistributed Scotch graph')
        end if


    end function scotch_dgraphredist


    function scotch_dgraphout(dgraph, local_cell_list) result(ierr)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(out) :: local_cell_list(*)

        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphout(dgraph_ptr, cell_list) bind(C, name='scotchm_dgraphout') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: cell_list(*)
                integer(c_int) :: err
            end function scotchfdgraphout
        end interface

        ierr = scotchfdgraphout(c_loc(dgraph), local_cell_list)


    end function scotch_dgraphout


end module mpas_ptscotch_interface
#endif