# MirrorTracing
Mirror tracing protocol designed to study sleep and procedural memory in preschoolers (NIH F32HD117609). 

Maze images are nested according to a randomly assigned grouping variable and session. Children are presented with the task in 4 sessions: 
- encoding (5 images)
- immediate retrieval (3 images)
- delayed retrieval after 12h (delayed12) (3 images)
- delayed retrieval after 24h (delayed24) (3 images)

Extracted task performance variables include:
- Latency (ms): time to begin drawing in bounds 
- DrawTime (ms): time spent drawing in bounds
- ErrorTime (ms): time spent drawing out of bounds
- MazeInBoundsPixels: number of pixels in the total image considered in bounds
- MazeOutOfBoundsPixels: number of pixels in the total image considered out of bounds
- DrawnInBoundsPixels: number of pixels drawn in bounds 
- DrawnOutOfBoundsPixels: number of pixels drawn out of bounds 

In it's current form, the task is ideal for a touchscreen laptop. It can be launched from the terminal. Data are exported to a .csv file and automatically saved to the Desktop. 
