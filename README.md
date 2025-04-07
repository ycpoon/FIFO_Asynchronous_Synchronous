# Improved FIFO: Asynchronous Multi-Feature FIFO, Synchronous Multi-Feature FIFO, Simple FIFO

This repo implements three different versions of fifo. 

- "Simple_FIFO.sv" implements a simple synchronous FIFO with basic requirements.
- "Sync_FIFO.sv" implements a synchronous FIFO with various additional features and flags for various purpose.
- "Async_FIFO.sv" implements a asynchronous FIFO with features from Sync_FIFO and CDC between read and write.

## Synchronous FIFO Features
- Scalable write and read size for different use cases
- Adjustable FIFO depth for different memory requirements
- Configurable Almost Full & Almost Empty flag reminders
- Datacount register for tracking the amount of data currently in the FIFO
- Readable & Writeable Datacount for tracking the amount of space available for write and read.

Latency: 
- 0 clk_cycles for read operation to read flags, write operation to write flags

## Asynchronous FIFO features
- All Synchrnous FIFO features
- Zero clock latency for write operation to write flags and read operation to read flags.
- Two Flop Synchronization and Binary/Gray Code Conversion for accurate synchronization of read and write.
- Capable of Synchronizing Write Clock and Read Clock that is less than 1.5x faster/slower than the other.

Latency: 
- 0 clk_cycles for read operation to read flags, write operation to write flags
- 1 wr_clk + 2 rd_clk cycles for write operation to read flags
- 1 rd_clk + 2 wr_clk cycles for read operation to write flag

## Testing
- "FIFO_test.sv" implements the top-level test
- "FIFO_sva.svh" implements the assertions for FIFO formal verification

Tested using assertion-based verification, testing framework laid out for Simple FIFO, and fully tested

Next Steps: Adjust the framework for Synchronous FIFO and Asynchronous FIFO

## Next Steps
- Apply other synchronizers (toggle/4-phase handshake) to support bigger frequency difference in read and write clock.
- Different read & write width results in multi bit changes even in gray code during synchronization due to non-sequential increments in pointers, find and design a solution to reduce bit changes in cases where   
- Program and Integrate a GUI to initialize the values for the parameters