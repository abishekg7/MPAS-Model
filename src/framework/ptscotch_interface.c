/*
 * Copyright (c) 2023, The University Corporation for Atmospheric Research (UCAR).
 *
 * Unless noted otherwise source code is licensed under the BSD license.
 * Additional copyright and license information can be found in the LICENSE file
 * distributed with this code, or at http://mpas-dev.github.com/license.html
 */

#include <stddef.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <mpi.h>
#include "ptscotch.h"


///#ifdef _MPI

///#endif

#define MSGSIZE 256

SCOTCH_Dgraph       dgrfdat;


typedef struct Dgraph_ {
  unsigned int                flagval;              /*+ Graph properties                                          +*/
  int                      baseval;              /*+ Base index for edge/vertex arrays                         +*/
  int                      vertglbnbr;           /*+ Global number of vertices                                 +*/
  int                      vertglbmax;           /*+ Maximum number of local vertices over all processes       +*/
  int                      vertgstnbr;           /*+ Number of local + ghost vertices                          +*/
  int                      vertgstnnd;           /*+ vertgstnbr + baseval                                      +*/
  int                      vertlocnbr;           /*+ Local number of vertices                                  +*/
  int                      vertlocnnd;           /*+ Local number of vertices + baseval                        +*/
  int *                    vertloctax;           /*+ Local vertex beginning index array [based]                +*/
  int *                    vendloctax;           /*+ Local vertex end index array [based]                      +*/
  int *                    veloloctax;           /*+ Local vertex load array if present                        +*/
  int                      velolocsum;           /*+ Local sum of all vertex loads                             +*/
  int                      veloglbsum;           /*+ Global sum of all vertex loads                            +*/
  int *                    vnumloctax;           /*+ Arrays of global vertex numbers in original graph         +*/
  int *                    vlblloctax;           /*+ Arrays of vertex labels (when read from file)             +*/
  int                      edgeglbnbr;           /*+ Global number of arcs                                     +*/
  int                      edgeglbmax;           /*+ Maximum number of local edges over all processes          +*/
  int                      edgelocnbr;           /*+ Number of local edges                                     +*/
  int                      edgelocsiz;           /*+ Size of local edge array (= edgelocnbr when compact)      +*/
  int                      edgeglbsmx;           /*+ Maximum size of local edge arrays over all processes      +*/
  int *                    edgegsttax;           /*+ Edge array holding local indices of neighbors [based]     +*/
  int *                    edgeloctax;           /*+ Edge array holding global neighbor numbers [based]        +*/
  int *                    edloloctax;           /*+ Edge load array                                           +*/
  int                      degrglbmax;           /*+ Maximum degree over all processes                         +*/
  int                       pkeyglbval;           /*+ Communicator key value: folded communicators are distinct +*/
  MPI_Comm                  proccomm;             /*+ Graph communicator                                        +*/
  int                       procglbnbr;           /*+ Number of processes sharing graph data                    +*/
  int                       proclocnum;           /*+ Number of this process                                    +*/
  int *                    procvrttab;           /*+ Global array of vertex number ranges [+1,based]           +*/
  int *                    proccnttab;           /*+ Count array for local number of vertices                  +*/
  int *                    procdsptab;           /*+ Displacement array with respect to proccnttab [+1,based]  +*/
  int                       procngbnbr;           /*+ Number of neighboring processes                           +*/
  int                       procngbmax;           /*+ Maximum number of neighboring processes                   +*/
  int *                     procngbtab;           /*+ Array of neighbor process numbers [sorted]                +*/
  int *                     procrcvtab;           /*+ Number of vertices to receive in ghost vertex sub-arrays  +*/
  int                       procsndnbr;           /*+ Overall size of local send array                          +*/
  int *                     procsndtab;           /*+ Number of vertices to send in ghost vertex sub-arrays     +*/
  int *                     procsidtab;           /*+ Array of indices to build communication vectors (send)    +*/
  int                       procsidnbr;           /*+ Size of the send index array                              +*/
} Dgraph;


/*
 *  Interface routines for writing log messages; defined in mpas_log.F
 *  messageType_c may be any of "MPAS_LOG_OUT", "MPAS_LOG_WARN", "MPAS_LOG_ERR", or "MPAS_LOG_CRIT"
 */
int scotchm_dgraphinit(void * ptr, int localcomm)
//int scotchm_dgraphinit(int localcomm)
{
	MPI_Comm comm;
	MPI_Comm comm2;

	int size, rank, err;

	comm = MPI_Comm_f2c((MPI_Fint)localcomm);

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;
   
   err = SCOTCH_dgraphInit(dgraph, comm);


   Dgraph * my_dgraph = (Dgraph *) dgraph;

	printf("In scotchm_dgraphinit: After SCOTCH_dgraphInit: = %d \n",my_dgraph->procglbnbr);
	printf("In scotchm_dgraphinit: After SCOTCH_dgraphInit: = %d \n",my_dgraph->proclocnum);

	comm2 = my_dgraph->proccomm;

	MPI_Comm_size (comm2, &size); /* Get communicator data */
  	MPI_Comm_rank (comm2, &rank);

	printf("In scotchm_dgraphinit: MPI_Comm size = %d, rank = %d\n",size, rank);


	return err;

}

int scotchm_dgraphbuild(void * ptr,
					   int nVertices, 
                       int * vertloctab_1,     
                       int nLocEdgesGraph, 
                       int edgelocsiz, 
                       int *adjncy
)
{
	int baseval = 1; // Fortran-style 1-based indexing
	int vertlocnbr = nVertices;
	int * vertloctab = vertloctab_1;
	int * vendloctab = vertloctab_1 + 1;
	int * veloloctab = NULL; // vertex weights not used
	int * vlblloctab = NULL; // vertex labels not used
	int edgelocnbr = nLocEdgesGraph;
	int *edgeloctab = adjncy;
	int * edgegsttab = NULL; // Optional array holding the local and ghost indices
	int * edloloctab = NULL; // Optional array of integer loads for each local edge
	int i,err;

	

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;	

	Dgraph * my_dgraph = (Dgraph *) dgraph;

	for (int i=0; i < nVertices+1; i++) {
		printf("before scotchm_dgraphbuild: rank: %d vertloctab(%d) = %d \n",my_dgraph->proclocnum, i, vertloctab[i]);
	}
	for (int i=0; i < nLocEdgesGraph; i++) {
		printf("before scotchm_dgraphbuild: rank: %d edgeloctab(%d) = %d \n",my_dgraph->proclocnum, i, edgeloctab[i]);
	}

	err = SCOTCH_dgraphBuild (dgraph,
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

	

	printf("In scotchm_dgraphbuild: rank: %d vertglbnbr = %d \n",my_dgraph->proclocnum, my_dgraph->vertglbnbr);
	printf("In scotchm_dgraphbuild: rank: %d vertlocnbr = %d \n",my_dgraph->proclocnum, my_dgraph->vertlocnbr);

	for (int i=0; i < nVertices+1; i++) {
		printf("In scotchm_dgraphbuild: rank: %d vertloctab(%d) = %d \n",my_dgraph->proclocnum, i, my_dgraph->vertloctax[i]);
	}
	for (int i=0; i < nLocEdgesGraph; i++) {
		printf("In scotchm_dgraphbuild: rank: %d edgeloctab(%d) = %d \n",my_dgraph->proclocnum, i, my_dgraph->edgeloctax[i]);
	}

	return err;

}

int scotchm_dgraphcheck(void * ptr)
{

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;

	return SCOTCH_dgraphCheck(dgraph);
}



int scotchm_dgraphpart(void * ptr, int num_part, void * ptr_strat, int * parttab){

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;
	SCOTCH_Strat *strat = (SCOTCH_Strat *) ptr_strat;

	return SCOTCH_dgraphPart(dgraph, num_part, strat, parttab);
}

int scotch_dgraphredist(void * ptr, int *partloctab, void * ptr_out){


	SCOTCH_Dgraph *dgraph_in = (SCOTCH_Dgraph *) ptr;
	SCOTCH_Dgraph *dgraph_out = (SCOTCH_Dgraph *) ptr_out;
	int * permgsttab = NULL; // Redistribution permutation array
	int vertlocdlt = 0; // Extra size of local vertex array 
	int edgelocdlt = 0; // Extra size of local edge array

	return SCOTCH_dgraphRedist (dgraph_in, partloctab, permgsttab, vertlocdlt, edgelocdlt, dgraph_out);
}

// int scotchfdgraphdata()
// {
// 	void                        SCOTCH_dgraphData   (const SCOTCH_Dgraph * const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num ** const, SCOTCH_Num ** const, SCOTCH_Num ** const, SCOTCH_Num ** const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num * const, SCOTCH_Num ** const, SCOTCH_Num ** const, SCOTCH_Num ** const, MPI_Comm * const);
// }

void scotchm_dgraphexit(SCOTCH_Dgraph *dgraph)
{

	return SCOTCH_dgraphExit(dgraph);
}

int scotchm_stratinit(void * strat_ptr)
{
		SCOTCH_Strat *strat = (SCOTCH_Strat *) strat_ptr;

		return  SCOTCH_stratInit(strat);
}

// int scotchfstratexit()
// {
// 	void                        SCOTCH_stratExit    (SCOTCH_Strat * const);
// }
