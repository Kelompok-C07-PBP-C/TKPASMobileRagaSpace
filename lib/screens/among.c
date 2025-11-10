#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#define NUM_WORKERS 4
sem_t start_semaphores[NUM_WORKERS];
char prefix[100];



void* worker4(void* arg) {
 printf("%s 1: Using the tool...\n", prefix);
 sleep(1);
 printf("%s 1: Done with the tool.\n", prefix);
 sem_post(&start_semaphores[2]);
 return NULL;
}
void *worker3(void *arg) {
 pthread_create(&threads[3], NULL, worker4, NULL);
 sem_wait(&start_semaphores[2]);
 printf("%s 1: Using the tool...\n", prefix);
 sleep(1);
 printf("%s 1: Done with the tool.\n", prefix);
 sem_post(&start_semaphores[1]);
 return NULL;
}
void *worker2(void *arg) {
 pthread_t * threads = (pthread_t *) arg;
 pthread_create(&threads[2], NULL, worker3, NULL);
 sem_wait(&start_semaphores[1]);
 printf("%s 1: Using the tool...\n", prefix);
 sleep(1);
 printf("%s 1: Done with the tool.\n", prefix);
 sem_post(&start_semaphores[0]);
 return NULL;
}
void *worker1(void *arg) {
 pthread_t * threads = (pthread_t *) arg;
 pthread_create(&threads[1], NULL, worker2, NULL);
 sem_wait(&start_semaphores[0]);
 printf("%s 1: Using the tool...\n", prefix);
 sleep(1);
 printf("%s 1: Done with the tool.\n", prefix);
 return NULL;
}
int main(int argc, char* argv[]) {
  pthread_t threads[NUM_WORKERS];
 
  printf("Enter prefix string: \n");
    if (scanf("%99s", prefix) != 1) {
       fprintf(stderr, "Failed to read prefix string\n");
       return 1;
    }
  for (int i = 0; i < NUM_WORKERS; i++) {
    sem_init(&start_semaphores[i], 0, 0);
   }
  pthread_create(&threads[0], NULL, worker1, (void *) threads);
  
  for (int i = 0; i < NUM_WORKERS; i++) {
    pthread_join(threads[i], NULL);
  }
  for (int i = 0; i < NUM_WORKERS; i++) {
    sem_destroy(&start_semaphores[i]);
  }
  return 0;
}