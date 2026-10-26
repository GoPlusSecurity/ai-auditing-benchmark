    address private constant DEFAULT_CONFIG = address(0);
    // reserved values for
    uint8 internal constant DEFAULT = 0;
    uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
    uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
    // 127 to prevent total number of DVNs (127 * 2) exceeding uint8.max (255)
    // by limiting the total size, it would help constraint the design of DVNOptions
    uint8 private constant MAX_COUNT = (type(uint8).max - 1) / 2;

    mapping(address oapp => mapping(uint32 eid => UlnConfig)) internal ulnConfigs;
