# c1p2 isolated-flit latency

Mean input-Req to output-Req latency: **0.7726 ns**.

Same frozen r3 low-switching, output-paced five-flit test as Thin 0.6556 ns; only geometry bindings changed. This is not packet completion divided by five. MAXIMUM SDF, TT 0.8 V 25 C, post-synthesis. Five flits delivered; GLS PASS, zero SDF errors, no timing violations.

Cell sizing targets match the Thin recipe. The geometry-specific mapped XNR4 count is checked as exactly 8; all are sized to D2. The initial run with the c1p4-derived count check is retained separately.
