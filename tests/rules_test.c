#include "../src/include/module.h"
#include "deps/runner.h"
#include <stdbool.h>

bool test_module_add() {
    int result = module_add(1, 2);

    return result == 3;
}

int main() {
    Runner* runner = runner_init("rules");
    runner->test("1 + 2 should be 3", test_module_add);
    runner_free(runner);
    return 0;
}
