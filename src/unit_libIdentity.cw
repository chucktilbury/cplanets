include "lib/machine.cw"

start {
    Machine machine = Machine()
    String<> identity = machine.identity
    if (identity().equals("cplanets-lib")) {
        print("true\n")
    } else {
        print("false\n")
    }
}
