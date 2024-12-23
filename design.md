# Chunked Cell Memory Model

This document describes a **chunked cell memory model**, designed for use in systems with constrained resources, such as Z80-based microprocessors. The model balances memory efficiency and simplicity.

## Overview

- **28 bytes of payload**: Used for storing data, divided into smaller structures.
- **2 bytes for pointer**: Used to link cells together, creating a logical chain or list.
- **1 byte for length**: Tracks the number of used elements in the payload.
- **1 unused byte**: Reserved for future use or expansion.

This design allows efficient traversal and dynamic data management, minimizing pointer overhead while leveraging structured payloads.

## Key Features

### Structure Layout

- **Payload**: Contains up to **7 elements** of 4 bytes each, providing space for small structures or compact data.
- **Pointer**: A 16-bit value linking to the next chunk in the chain.
- **Length**: A single byte to record the number of used elements (3 bits needed for a maximum of 7).
- **Unused Bytes**: Reserved for future use.

Each cell is aligned to **32 bytes**, ensuring predictable memory layout and simplifying pointer arithmetic.

### Pointer Optimization

- The **11 most significant bits** of the pointer are used to address up to **2048 chunks** within a 64KB memory space, due to the 32-byte alignment.
- Only **3 bits** are required to represent the length (max 7).
- This leaves **18 additional bits** (5 + 5 + 8) that can be used for:
  - **Flags**: Application-specific metadata or control flags.
  - **Type Information**: Encoding data types for the payload.

### Benefits

1. **Efficient Memory Usage**: Reduces pointer overhead by grouping multiple elements in a single chunk.
2. **Simple Alignment**: Keeps all cells aligned to 32 bytes, minimizing fragmentation and ensuring fast pointer calculations.
3. **Embedded Metadata**: Leverages pointer bits to store additional information, avoiding separate metadata structures.
4. **Scalability**: Supports up to 2048 chunks within a 64KB memory space.

## Example Layout

### Chunk Structure

```
[Payload (28 bytes)] [Pointer (2 bytes)] [Length (1 byte)] [Unused (1 byte)]
```

### Pointer Encoding

- Example: `11010 000 00000001001`
  - **Type**: `11` (Custom type).
  - **Flags**: Reserved bits for application-specific metadata.
  - **Index**: Points to the 10th chunk (aligned at `10 * 32 = 320` bytes).

## Supported Operations

### Traversal

1. Start at the head chunk.
2. Follow the **pointer index** to the next chunk.
3. Use the **length** field to determine valid elements in each payload.

### Insertion

1. Check the **length field** for available space.
2. If space is available, insert the element and increment the length.
3. If the chunk is full, allocate a new chunk, link it via the pointer, and insert the element.

### Deletion

1. Locate the element to delete.
2. Shift subsequent elements left within the payload.
3. Decrement the length field.
4. If the chunk becomes empty, update the previous chunk’s pointer.

### Concatenation

1. Update the **pointer field** of the last chunk in the first list to point to the head of the second list.

## Trade-offs

### Pros

- Significantly reduces pointer overhead compared to traditional linked lists.
- Improves locality of reference for sequential access.
- Supports dynamic payload sizes with minimal wasted space.

### Cons

- Leaves 1 byte unallocated per 32-byte payload.
- Limited flexibility for payload sizes larger than 28 bytes without structural changes.

## Use Cases

This memory model is ideal for:

- Systems with constrained resources, such as microcontrollers.
- Applications requiring efficient list or buffer management with dynamic elements.
- Scenarios where type-specific operations are common, leveraging embedded type metadata.

