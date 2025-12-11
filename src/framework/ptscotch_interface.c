/*
 * Copyright (c) 2025, The University Corporation for Atmospheric Research (UCAR).
 *
 * Unless noted otherwise source code is licensed under the BSD license.
 * Additional copyright and license information can be found in the LICENSE file
 * distributed with this code, or at http://mpas-dev.github.com/license.html
 */
#ifdef MPAS_SCOTCH
#include <stddef.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <mpi.h>
#include "ptscotch.h"


/********************************************************************************
 *
 * scotchm_dgraphinit
 *
 * Initialize a SCOTCH distributed graph object using a Fortran MPI communicator.
 *
 * Parameters:
 *   ptr        - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *   localcomm  - Fortran MPI communicator handle (`MPI_Fint`) passed as `int`
 *
 * Returns:
 *   integer error code returned by `SCOTCH_dgraphInit` (0 on success).
 *
 ********************************************************************************/
int scotchm_dgraphinit(void *ptr, int localcomm)
{
	MPI_Comm comm;
	MPI_Comm comm2;
	int size, rank, err;

	comm = MPI_Comm_f2c((MPI_Fint)localcomm);

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *)ptr;

	err = SCOTCH_dgraphInit(dgraph, comm);

	return err;
}


/********************************************************************************
 *
 * scotchm_dgraphbuild
 *
 * Build a SCOTCH distributed graph from local vertex/edge arrays.
 *
 * Parameters:
 *   ptr               - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *   nVertices         - number of local vertices
 *   vertloctab_1      - pointer to Fortran-style vertex index array (based)
 *   nLocEdgesGraph    - number of local edges in the distributed graph
 *   edgelocsiz_1      - size of the local edge array
 *   adjncy            - adjacency list array (edge destinations)
 *
 * Returns:
 *   integer error code returned by `SCOTCH_dgraphBuild` (0 on success).
 *
 ********************************************************************************/
int scotchm_dgraphbuild(void *ptr,
						SCOTCH_Num nVertices,
						SCOTCH_Num *vertloctab_1,
						SCOTCH_Num nLocEdgesGraph,
						SCOTCH_Num edgelocsiz_1,
						SCOTCH_Num *adjncy)
{
	SCOTCH_Num baseval = 1; /* Fortran-style 1-based indexing */
	SCOTCH_Num vertlocnbr = nVertices;
	SCOTCH_Num *veloloctab = NULL; /* vertex weights not used */
	SCOTCH_Num *vlblloctab = NULL; /* vertex labels not used */
	SCOTCH_Num edgelocnbr = nLocEdgesGraph;
	SCOTCH_Num edgelocsiz = edgelocsiz_1;
	SCOTCH_Num *edgegsttab = NULL; /* Optional array holding the local and ghost indices */
	SCOTCH_Num *edloloctab = NULL; /* Optional array of integer loads for each local edge */

	SCOTCH_Num *vertloctab = (SCOTCH_Num *)vertloctab_1;
	SCOTCH_Num *vendloctab = vertloctab_1 + 1;
	SCOTCH_Num *edgeloctab = (SCOTCH_Num *)adjncy;

	int i, err;

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *)ptr;

	err = SCOTCH_dgraphBuild(dgraph,
							 baseval,
							 vertlocnbr,
							 vertlocnbr,
							 vertloctab,
							 vendloctab,
							 veloloctab,
							 vlblloctab,
							 edgelocnbr,
							 edgelocsiz,
							 edgeloctab,
							 edgegsttab,
							 edloloctab);

	return err;
}


/********************************************************************************
 *
 * scotchm_dgraphcheck
 *
 * Perform an internal consistency check of a SCOTCH distributed graph.
 *
 * Parameters:
 *   ptr - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *
 * Returns:
 *   integer error code returned by `SCOTCH_dgraphCheck` (0 on success).
 *
 ********************************************************************************/
int scotchm_dgraphcheck(void *ptr)
{
	return SCOTCH_dgraphCheck((SCOTCH_Dgraph *)ptr);
}


/********************************************************************************
 *
 * scotchm_dgraphpart
 *
 * Partition the distributed graph into `num_part` parts using the provided
 * SCOTCH strategy object.
 *
 * Parameters:
 *   ptr       - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *   num_part  - number of partitions
 *   ptr_strat - pointer to a `SCOTCH_Strat` structure (as `void *`)
 *   parttab   - output array receiving part numbers for local vertices
 *
 * Returns:
 *   integer error code returned by `SCOTCH_dgraphPart` (0 on success).
 *
 ********************************************************************************/
int scotchm_dgraphpart(void *ptr, SCOTCH_Num num_part, void *ptr_strat, SCOTCH_Num *parttab)
{
	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *)ptr;
	SCOTCH_Strat *strat = (SCOTCH_Strat *)ptr_strat;

	return SCOTCH_dgraphPart(dgraph, num_part, strat, parttab);
}


/********************************************************************************
 *
 * scotchm_dgraphredist
 *
 * Redistribute a distributed SCOTCH graph given the partition table.
 *
 * Parameters:
 *   ptr         - pointer to input `SCOTCH_Dgraph` structure (as `void *`)
 *   partloctab  - partition table for local vertices
 *   ptr_out     - pointer to output `SCOTCH_Dgraph` structure (as `void *`)
 *   vertlocnbr  - pointer to return the number of local vertices in output
 *
 * Returns:
 *   integer error code returned by `SCOTCH_dgraphRedist` (0 on success).
 *
 ********************************************************************************/
int scotchm_dgraphredist(void *ptr, SCOTCH_Num *partloctab, void *ptr_out, SCOTCH_Num *vertlocnbr)
{
	SCOTCH_Dgraph *dgraph_in = (SCOTCH_Dgraph *)ptr;
	SCOTCH_Dgraph *dgraph_out = (SCOTCH_Dgraph *)ptr_out;
	SCOTCH_Num *permgsttab = NULL; /* Redistribution permutation array */
	SCOTCH_Num vertlocdlt = 0;     /* Extra size of local vertex array */
	SCOTCH_Num edgelocdlt = 0;     /* Extra size of local edge array */
	int err;

	err = SCOTCH_dgraphRedist(dgraph_in, partloctab, permgsttab, vertlocdlt, edgelocdlt, dgraph_out);

	// Call SCOTCH_dgraphSize to obtain the number of local vertices in the redistributed graph
	SCOTCH_dgraphSize(dgraph_out, NULL, vertlocnbr, NULL, NULL);

	return err;
}

/********************************************************************************
 *
 * scotchm_dgraphdata
 *
 * Extract vertex labels (or stored IDs) for local vertices into `cell_list`.
 *
 * Parameters:
 *   ptr        - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *   cell_list  - output array to receive vertex labels for local vertices
 *
 * Returns:
 *   integer error code (currently returns the local `err` variable; 0 on success).
 *
 ********************************************************************************/
void scotchm_dgraphdata(void *ptr, SCOTCH_Num *cell_list)
{
	
	int err;

	SCOTCH_Num vertlocnbr;	
	SCOTCH_Num *vlblloctab; /* vertex labels */

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *)ptr;

	SCOTCH_dgraphData(dgraph, NULL, NULL, &vertlocnbr, NULL, NULL, 
		             NULL, NULL, NULL, &vlblloctab,
					 NULL, NULL, NULL, 
					 NULL, NULL, NULL, NULL);

	// Copy vertex labels to output array
	for (SCOTCH_Num i = 0; i < vertlocnbr; i++) {
		cell_list[i] = vlblloctab[i];
	}

}


/********************************************************************************
 *
 * scotchm_dgraphexit
 *
 * Finalize/cleanup a `SCOTCH_Dgraph` object.
 *
 * Parameters:
 *   ptr - pointer to a `SCOTCH_Dgraph` structure (as `void *`)
 *
 * Returns:
 *   nothing (wraps `SCOTCH_dgraphExit`).
 *
 ********************************************************************************/
void scotchm_dgraphexit(void *ptr)
{
	SCOTCH_dgraphExit((SCOTCH_Dgraph *)ptr);
}


/********************************************************************************
 *
 * scotchm_stratinit
 *
 * Initialize a SCOTCH strategy object and build a default strategy for
 * distributed graph mapping.
 *
 * Parameters:
 *   strat_ptr - pointer to a `SCOTCH_Strat` structure (as `void *`)
 *
 * Returns:
 *   integer (0 on success).
 *
 ********************************************************************************/
int scotchm_stratinit(void *strat_ptr)
{
	SCOTCH_stratInit((SCOTCH_Strat *)strat_ptr);
	
	// This was required to avoid crashes when scaling up to large core counts
	SCOTCH_stratDgraphMapBuild((SCOTCH_Strat *)strat_ptr, SCOTCH_STRATSCALABILITY, 1, 0, 0.05);

	return 0;
}


/* ********************************************************************************
 *
 * scotchm_stratexit
 *
 * Finalize/cleanup a `SCOTCH_Strat` strategy object.
 *
 * Parameters:
 *   strat_ptr - pointer to a `SCOTCH_Strat` structure (as `void *`)
 *
 * Returns:
 *   nothing (wraps `SCOTCH_stratExit`).
 *
 ********************************************************************************/
void scotchm_stratexit(void *strat_ptr)
{
	SCOTCH_stratExit((SCOTCH_Strat *)strat_ptr);
}
#endif