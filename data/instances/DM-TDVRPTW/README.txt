Some information on the datasets.
	- The instances are in a two-depot version, meaning that the depot is split in two vertices.
	- The number of vertices in the digraph is n, meaning that the start depot is always 0 and the end depot is n-1.
	- Each vertex has an associated demand (q_0 = q_n+1 = 0), a time window (a_i, b_i), and a service time (s_0 = s_n+1 = 0).
	- There is an infinite number of vehicles, but each has a load capacity of Q.
	- We use the time-dependent model proposed in Ichoua et al (2003), where the horizon [0, T] is split in H speed zones [T_i, T_i+1] for i \in 1..H.
		* Each arc belongs to a cluster c_ij.
		* Each cluster has a speed in each speed zone s_ch.
		* Each arc has a distance d_ij.
	- ONLY ON PRICING INSTANCES: we have a profit (p_i) associated with each vertex i \in V.

Note that each dataset has an index.json file with all the instances listed and a solutions.json file with the Best Known Solution for each instance, indicating the routes with their departing time and duration.

The instances are in the following JSON format:
{
	"digraph":
	{
		"vertex_count": Number, // number of vertices in the digraph (including depots).
		"arc_count": Number, // number of arcs in the complete digraph.
		"arcs": Matrix<1|0>, // Adjacency matrix of the complete digraph.
		"coordinates": [[x, y]], // coordinate of each vertex in the plane.
	},
	"start_depot": Number, // vertex index of start depot (always 0).
	"end_depot": Number, // vertex index of end depot (always n-1).
	"distances": Matrix<Number>, // distance matrix.
	"capacity": Number, // Capacity of the vehicles (Q).
	"demands": [Number], // Array with vertex demands (q).
	"service_times": [Number], // Array with service times (s).
	"time_windows": [[Number, Number]], // Array with time windows (a_i, b_i).
	"horizon": [Number, Number], // Pair of numbers indicating the horizon [0, T].
	"speed_zone_count": Number, // number of speed zones in the instances.
	"speed_zones": [[Number, Number]], // Array with speed zones partition of the horizon ([T_i, T_i+1]).
	"cluster_count": Number, // Number of clusters in the instance.
	"clusters": Matrix<Number>, // cluster matrix (c_ij is the cluster of arc ij).
	"cluster_speeds": Matrix<Number>, // speed matrix (s_ch is the speed of cluster c in speed zone h).
	"profits": [Number], // (Only in pricing instances), array of profits for each vertex (p_i).
}