#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
   int i=0, count=atoi(argv[1]);
   for (; i<count; i++) {
      if (i == count - 1) {
         i = 0;
         usleep(1);
      }
   }
   return 0;
}
