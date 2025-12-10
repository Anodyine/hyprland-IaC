import struct

def make_edid():
    # --- HEADER ---
    # Fixed header: 00 FF FF FF FF FF FF 00
    header = b'\x00\xff\xff\xff\xff\xff\xff\x00'
    # Manufacturer: GIM, Code 1234, Serial 1, Week 1, Year 2024
    mfg = b'\x1c\xec\xd2\x04\x01\x00\x00\x00\x01\x22'
    # EDID Version 1.4
    version = b'\x01\x04'
    # Basic Params: Digital input, 40x30cm, Gamma 2.2
    params = b'\x95\x28\x1e\x78\xeb\x9c\x20\xa0\x57\x4f\xa2\x28\x0f\x50\x54'

    # --- ESTABLISHED TIMINGS ---
    # 720x400, 640x480, 800x600, 1024x768 (Safe fallbacks)
    established = b'\xbf\xef\x80'

    # --- STANDARD TIMINGS ---
    # Slot 1: 1920x1080 @ 60Hz (D1C0) - Backup
    # Slot 2: 1920x1200 @ 60Hz (D1F0) - Backup
    # Others unused (0101)
    standard = b'\xd1\xc0\xd1\xf0\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01'

    # --- DETAILED TIMING 1 (Preferred) ---
    # 1920x1440 @ 60Hz (CVT-RB - Reduced Blanking)
    # Pixel Clock: 173.00 MHz (Much lower than 234MHz!)
    # Bytes: 94 43 80 A0 70 A0 2E 50 30 20 35 00 00 00 00 00 00 1A
    dt1 = b'\x94\x43\x80\xa0\x70\xa0\x2e\x50\x30\x20\x35\x00\x00\x00\x00\x00\x00\x1a'

    # --- DETAILED TIMING 2 ---
    # 1920x1080 @ 60Hz (Standard)
    # Just in case 1440p fails, this keeps the monitor alive.
    dt2 = b'\x02\x3a\x80\x18\x71\x38\x2d\x40\x58\x2c\x45\x00\x00\x00\x00\x00\x00\x1e'

    # --- DESCRIPTOR 3: Name ---
    # Name: OMARCHY
    d3 = b'\x00\x00\x00\xfc\x00\x4f\x4d\x41\x52\x43\x48\x59\x0a\x20\x20\x20\x20\x20'

    # --- DESCRIPTOR 4: Range Limits ---
    d4 = b'\x00\x00\x00\xfd\x00\x17\x3d\x0f\x50\x11\x00\x0a\x20\x20\x20\x20\x20\x20'

    # Extensions (0)
    ext = b'\x00'

    # Concatenate body
    body = header + mfg + version + params + established + standard + dt1 + dt2 + d3 + d4 + ext

    # Calculate Checksum
    checksum = (256 - (sum(body) % 256)) % 256

    final_edid = body + bytes([checksum])

    with open("edid.bin", "wb") as f:
        f.write(final_edid)
    print("Generated edid.bin with 1920x1440 (RB) and valid Checksum.")

if __name__ == "__main__":
    make_edid()

