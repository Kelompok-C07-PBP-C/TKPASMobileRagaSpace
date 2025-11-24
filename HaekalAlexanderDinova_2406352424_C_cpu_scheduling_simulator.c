#include <stdio.h>
#include <string.h>

/*
 * CPU Scheduling Simulator
 *
 * Fitur:
 * - Input proses: manual (keyboard) atau dari file teks.
 *   Format tiap baris proses: NamaProses AT BT PR
 *   Contoh: P1 0 5 2
 *       AT = arrival time
 *       BT = burst time (lama CPU yang dibutuhkan)
 *       PR = priority (semakin kecil, semakin tinggi prioritas)
 *
 * - Algoritma yang didukung:
 *   1. FCFS               (First Come First Served, non-preemptive)
 *   2. SJF                (Shortest Job First, non-preemptive)
 *   3. Priority           (Preemptive)
 *   4. Round Robin        (Preemptive, quantum di-input user)
 *
 * - Output:
 *   - Gantt Chart ASCII (urutan eksekusi proses)
 *   - Tabel proses: Waiting Time, Turnaround Time, Response Time
 *   - Rata-rata WT, TAT, RT
 *   - Dapat dicetak ke layar atau disimpan ke file laporan.
 */

#define MAX_PROCESSES     100
#define MAX_GANTT_ENTRIES 1000
#define MAX_NAME_LEN      16
#define MAX_QUEUE_SIZE    (MAX_PROCESSES + 5)

/* Struktur proses yang digunakan oleh semua algoritma */
typedef struct {
    char pid[MAX_NAME_LEN];  /* nama proses (misal: "P1") */
    int at;                  /* arrival time */
    int bt;                  /* burst time awal */
    int bt_remaining;        /* burst time yang tersisa (untuk preemptive) */
    int priority;            /* semakin kecil angka, semakin tinggi prioritas */
    int ct;                  /* completion time (waktu selesai) */
    int tat;                 /* turnaround time = ct - at */
    int wt;                  /* waiting time = tat - bt */
    int rt;                  /* response time = waktu pertama kali jalan - at */
    int started;             /* flag: sudah pernah jalan atau belum */
} Process;

/* Satu entri Gantt chart: proses apa, mulai kapan, selesai kapan */
typedef struct {
    char pid[MAX_NAME_LEN];
    int start;
    int end;
} GanttEntry;

/* Struktur queue melingkar sederhana untuk Round Robin */
typedef struct {
    int data[MAX_QUEUE_SIZE];
    int front;
    int rear;
} Queue;

/* Inisialisasi queue kosong */
void init_queue(Queue *q) {
    q->front = q->rear = 0;
}

/* Mengecek apakah queue kosong */
int is_queue_empty(Queue *q) {
    return q->front == q->rear;
}

/* Menambah indeks proses ke dalam queue (jika belum penuh) */
void enqueue(Queue *q, int value) {
    int next = (q->rear + 1) % MAX_QUEUE_SIZE;
    if (next == q->front) {
        /* Queue penuh. Dengan batas MAX_QUEUE_SIZE yang besar,
         * kondisi ini seharusnya tidak terjadi dalam simulasi normal.
         */
        return;
    }
    q->data[q->rear] = value;
    q->rear = next;
}

/* Menghapus dan mengembalikan indeks proses dari depan queue */
int dequeue(Queue *q) {
    if (is_queue_empty(q)) return -1;
    int value = q->data[q->front];
    q->front = (q->front + 1) % MAX_QUEUE_SIZE;
    return value;
}

/* Mencari arrival time terkecil sebagai titik mulai simulasi waktu */
int get_min_arrival(Process procs[], int n) {
    int min = procs[0].at;
    for (int i = 1; i < n; i++) {
        if (procs[i].at < min) {
            min = procs[i].at;
        }
    }
    return min;
}

/* Input proses secara manual dari keyboard */
int read_processes_manual(Process procs[]) {
    int n;
    printf("Masukkan jumlah proses: ");
    if (scanf("%d", &n) != 1 || n <= 0 || n > MAX_PROCESSES) {
        printf("Jumlah proses tidak valid.\n");
        return -1;
    }

    printf("Masukkan data proses dalam format: NamaProses AT BT PR\n");
    for (int i = 0; i < n; i++) {
        printf("P%d: ", i + 1);
        if (scanf("%15s %d %d %d",
                  procs[i].pid,
                  &procs[i].at,
                  &procs[i].bt,
                  &procs[i].priority) != 4) {
            printf("Input tidak valid.\n");
            return -1;
        }
    }
    return n;
}

/* Input proses dari file teks.
 * Setiap baris: NamaProses AT BT PR
 */
int read_processes_file(const char *filename, Process procs[]) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        printf("Tidak bisa membuka file input '%s'.\n", filename);
        return -1;
    }

    int n = 0;
    while (n < MAX_PROCESSES &&
           fscanf(f, "%15s %d %d %d",
                  procs[n].pid,
                  &procs[n].at,
                  &procs[n].bt,
                  &procs[n].priority) == 4) {
        n++;
    }

    fclose(f);

    if (n == 0) {
        printf("File kosong atau format salah.\n");
        return -1;
    }

    return n;
}

/* FCFS (First Come First Served) - non-preemptive.
 * Proses dijalankan penuh sesuai urutan kedatangan.
 * Jika CPU menganggur, waktu akan dilompat ke arrival berikutnya.
 */
void schedule_fcfs(Process procs[], int n, GanttEntry gantt[], int *gantt_size) {
    int time = get_min_arrival(procs, n); /* mulai dari arrival terkecil */
    int completed = 0;                    /* jumlah proses yang sudah selesai */
    int current = -1;                     /* indeks proses yang sedang jalan */
    int prev = -1;                        /* indeks proses sebelumnya (untuk Gantt) */
    int segment_start = time;             /* waktu mulai segmen Gantt saat ini */
    *gantt_size = 0;

    while (completed < n) {
        int idx = -1;

        /* Pilih proses yang sudah datang dengan arrival time terkecil */
        for (int i = 0; i < n; i++) {
            if (procs[i].bt_remaining > 0 && procs[i].at <= time) {
                if (idx == -1 ||
                    procs[i].at < procs[idx].at ||
                    (procs[i].at == procs[idx].at && i < idx)) {
                    idx = i;
                }
            }
        }
        current = idx;

        /* Jika terjadi pergantian proses, tutup segmen Gantt sebelumnya */
        if (current != prev) {
            if (prev != -1) {
                strcpy(gantt[*gantt_size].pid, procs[prev].pid);
                gantt[*gantt_size].start = segment_start;
                gantt[*gantt_size].end = time;
                (*gantt_size)++;
            }
            if (current != -1) {
                segment_start = time;
            }
            prev = current;
        }

        if (current != -1) {
            /* FCFS non-preemptive, tetapi kita tetap jalan per 1 unit waktu
             * supaya mudah membuat Gantt chart.
             */
            if (!procs[current].started) {
                procs[current].rt = time - procs[current].at;
                procs[current].started = 1;
            }
            procs[current].bt_remaining--;
            if (procs[current].bt_remaining == 0) {
                procs[current].ct = time + 1;
                procs[current].tat = procs[current].ct - procs[current].at;
                procs[current].wt = procs[current].tat - procs[current].bt;
                completed++;
            }
            time++;
        } else {
            /* Tidak ada proses ready, CPU menganggur -> lompat ke arrival berikutnya */
            int next_at = -1;
            for (int i = 0; i < n; i++) {
                if (procs[i].bt_remaining > 0) {
                    if (next_at == -1 || procs[i].at < next_at) {
                        next_at = procs[i].at;
                    }
                }
            }
            if (next_at == -1) break;
            if (next_at > time) {
                time = next_at;
            } else {
                time++;
            }
        }
    }

    /* Tutup segmen terakhir jika ada */
    if (prev != -1) {
        strcpy(gantt[*gantt_size].pid, procs[prev].pid);
        gantt[*gantt_size].start = segment_start;
        gantt[*gantt_size].end = time;
        (*gantt_size)++;
    }
}

/* ==== Heap utilities (generic) untuk SJF & Priority ==== */

/* Comparator generic untuk heap: mengembalikan 1 jika proses i
 * "lebih baik" (lebih diprioritaskan) daripada proses j.
 * Implementasi konkrit ada di bawah (SJF & Priority).
 */
typedef int (*HeapCmp)(int i, int j, Process procs[]);

typedef struct {
    int data[MAX_PROCESSES];
    int size;
} Heap;

static void heap_init(Heap *h) {
    h->size = 0;
}

static void heap_swap(int *a, int *b) {
    int tmp = *a;
    *a = *b;
    *b = tmp;
}

/* Operasi push untuk min-heap generic */
static void heap_push(Heap *h, int idx, Process procs[], HeapCmp cmp) {
    int pos = h->size++;
    h->data[pos] = idx;

    while (pos > 0) {
        int parent = (pos - 1) / 2;
        if (cmp(h->data[pos], h->data[parent], procs)) {
            heap_swap(&h->data[pos], &h->data[parent]);
            pos = parent;
        } else {
            break;
        }
    }
}

/* Operasi pop minimal untuk min-heap generic */
static int heap_pop_min(Heap *h, Process procs[], HeapCmp cmp) {
    if (h->size == 0) return -1;

    int top = h->data[0];
    h->data[0] = h->data[h->size - 1];
    h->size--;

    int pos = 0;
    while (1) {
        int left = 2 * pos + 1;
        int right = 2 * pos + 2;
        int best = pos;

        if (left < h->size && cmp(h->data[left], h->data[best], procs)) {
            best = left;
        }
        if (right < h->size && cmp(h->data[right], h->data[best], procs)) {
            best = right;
        }
        if (best != pos) {
            heap_swap(&h->data[pos], &h->data[best]);
            pos = best;
        } else {
            break;
        }
    }

    return top;
}

/* Melihat elemen teratas heap tanpa menghapus */
static int heap_peek(const Heap *h) {
    return (h->size > 0) ? h->data[0] : -1;
}

/* Comparator khusus SJF: pilih burst time terkecil,
 * lalu arrival time, lalu indeks array.
 */
static int heap_cmp_sjf(int i, int j, Process procs[]) {
    if (procs[i].bt != procs[j].bt) {
        return procs[i].bt < procs[j].bt;
    }
    if (procs[i].at != procs[j].at) {
        return procs[i].at < procs[j].at;
    }
    return i < j;
}

/* Comparator khusus Priority (preemptive): priority terkecil,
 * lalu arrival time, lalu indeks array.
 */
static int heap_cmp_priority(int i, int j, Process procs[]) {
    if (procs[i].priority != procs[j].priority) {
        return procs[i].priority < procs[j].priority;
    }
    if (procs[i].at != procs[j].at) {
        return procs[i].at < procs[j].at;
    }
    return i < j;
}

/* SJF (Shortest Job First) - non-preemptive dengan heap.
 * Ketika CPU siap memilih proses, ia mengambil proses ready dengan BT
 * terkecil dari min-heap (priority queue berdasarkan burst time).
 */
void schedule_sjf(Process procs[], int n, GanttEntry gantt[], int *gantt_size) {
    int time = get_min_arrival(procs, n);
    int completed = 0;
    Heap heap;
    heap_init(&heap);
    int inserted[MAX_PROCESSES] = {0}; /* sudah dimasukkan ke heap atau belum */

    *gantt_size = 0;

    while (completed < n) {
        /* Masukkan proses yang sudah datang (AT <= time) ke heap sekali saja */
        for (int i = 0; i < n; i++) {
            if (!inserted[i] &&
                procs[i].bt_remaining > 0 &&
                procs[i].at <= time) {
                heap_push(&heap, i, procs, heap_cmp_sjf);
                inserted[i] = 1;
            }
        }

        if (heap.size == 0) {
            /* Tidak ada proses ready, lompat ke arrival berikutnya */
            int next_at = -1;
            for (int i = 0; i < n; i++) {
                if (procs[i].bt_remaining > 0) {
                    if (next_at == -1 || procs[i].at < next_at) {
                        next_at = procs[i].at;
                    }
                }
            }
            if (next_at == -1) break;
            time = next_at;
            continue;
        }

        /* Ambil proses dengan BT terkecil dari heap dan jalankan sampai selesai */
        int idx = heap_pop_min(&heap, procs, heap_cmp_sjf);

        int start = time;
        if (!procs[idx].started) {
            procs[idx].rt = start - procs[idx].at;
            procs[idx].started = 1;
        }

        /* Non-preemptive -> jalankan proses sampai selesai sekaligus */
        time += procs[idx].bt_remaining;

        strcpy(gantt[*gantt_size].pid, procs[idx].pid);
        gantt[*gantt_size].start = start;
        gantt[*gantt_size].end = time;
        (*gantt_size)++;

        procs[idx].bt_remaining = 0;
        procs[idx].ct = time;
        procs[idx].tat = procs[idx].ct - procs[idx].at;
        procs[idx].wt = procs[idx].tat - procs[idx].bt;
        completed++;
    }
}

/* Priority Scheduling (Preemptive) dengan heap.
 * Pada setiap satuan waktu, proses ready disimpan dalam min-heap berdasarkan
 * priority (dan arrival time / indeks sebagai tie-breaker). Heap ini
 * merepresentasikan "priority queue" sehingga proses dengan prioritas
 * tertinggi selalu diambil dari root heap.
 */
void schedule_priority_preemptive(Process procs[], int n, GanttEntry gantt[], int *gantt_size) {
    int time = get_min_arrival(procs, n);
    int completed = 0;
    int current = -1;                /* indeks proses yang sedang dieksekusi */
    int prev = -1;                   /* untuk mencatat pergantian di Gantt */
    int segment_start = time;
    Heap heap;
    heap_init(&heap);
    int inserted[MAX_PROCESSES] = {0}; /* sudah pernah dimasukkan ke heap sejak arrival */

    *gantt_size = 0;

    while (completed < n) {
        /* Masukkan proses yang sudah tiba (AT <= time) ke heap (sekali saja) */
        for (int i = 0; i < n; i++) {
            if (!inserted[i] &&
                procs[i].bt_remaining > 0 &&
                procs[i].at <= time) {
                heap_push(&heap, i, procs, heap_cmp_priority);
                inserted[i] = 1;
            }
        }

        /* Tentukan kandidat proses saat ini dan dari heap */
        int candidate_current =
            (current != -1 && procs[current].bt_remaining > 0) ? current : -1;
        int candidate_heap = heap_peek(&heap);
        int idx = -1;

        if (candidate_current == -1 && candidate_heap == -1) {
            /* Tidak ada proses ready: CPU idle.
             * Jika sebelumnya ada proses yang jalan, tutup segmen Gantt-nya.
             */
            if (prev != -1) {
                strcpy(gantt[*gantt_size].pid, procs[prev].pid);
                gantt[*gantt_size].start = segment_start;
                gantt[*gantt_size].end = time;
                (*gantt_size)++;
                prev = -1;
            }

            /* Lompat ke arrival time berikutnya dari proses yang belum selesai */
            int next_at = -1;
            for (int i = 0; i < n; i++) {
                if (procs[i].bt_remaining > 0) {
                    if (next_at == -1 || procs[i].at < next_at) {
                        next_at = procs[i].at;
                    }
                }
            }
            if (next_at == -1) break;
            if (next_at > time) {
                time = next_at;
            } else {
                time++;
            }
            continue;
        }

        if (candidate_current == -1) {
            /* Tidak ada proses yang sedang jalan -> ambil dari heap */
            idx = heap_pop_min(&heap, procs, heap_cmp_priority);
        } else if (candidate_heap == -1) {
            /* Hanya proses saat ini yang tersedia, tetap lanjut */
            idx = candidate_current;
        } else {
            /* Ada proses saat ini dan proses lain di heap:
             * jika heap root memiliki prioritas lebih tinggi, lakukan preemption.
             */
            if (heap_cmp_priority(candidate_heap, candidate_current, procs)) {
                heap_push(&heap, candidate_current, procs, heap_cmp_priority);
                idx = heap_pop_min(&heap, procs, heap_cmp_priority);
            } else {
                idx = candidate_current;
            }
        }

        current = idx;

        /* Tutup / buka segmen Gantt jika terjadi pergantian proses */
        if (current != prev) {
            if (prev != -1) {
                strcpy(gantt[*gantt_size].pid, procs[prev].pid);
                gantt[*gantt_size].start = segment_start;
                gantt[*gantt_size].end = time;
                (*gantt_size)++;
            }
            segment_start = time;
            prev = current;
        }

        /* Jalankan proses current selama 1 unit waktu */
        if (!procs[current].started) {
            procs[current].rt = time - procs[current].at;
            procs[current].started = 1;
        }
        procs[current].bt_remaining--;

        if (procs[current].bt_remaining == 0) {
            procs[current].ct = time + 1;
            procs[current].tat = procs[current].ct - procs[current].at;
            procs[current].wt = procs[current].tat - procs[current].bt;
            completed++;
        }

        time++;
    }

    /* Tutup segmen terakhir jika masih ada proses tercatat di prev */
    if (prev != -1) {
        strcpy(gantt[*gantt_size].pid, procs[prev].pid);
        gantt[*gantt_size].start = segment_start;
        gantt[*gantt_size].end = time;
        (*gantt_size)++;
    }
}

/* Round Robin (preemptive) dengan quantum tertentu.
 * Proses siap dimasukkan ke ready-queue (FIFO).
 * Tiap proses diberi jatah CPU sebesar "quantum" waktu secara bergiliran.
 */
void schedule_round_robin(Process procs[], int n, int quantum,
                          GanttEntry gantt[], int *gantt_size) {
    int time = get_min_arrival(procs, n);
    int completed = 0;
    int current = -1;
    int prev = -1;
    int segment_start = time;
    int quantum_counter = 0;       /* sudah berapa lama proses saat ini berjalan */
    int in_queue[MAX_PROCESSES] = {0};
    Queue q;

    init_queue(&q);
    *gantt_size = 0;

    while (completed < n) {
        /* Tambahkan proses yang baru tiba ke ready-queue (kecuali yang sedang jalan) */
        for (int i = 0; i < n; i++) {
            if (procs[i].bt_remaining > 0 &&
                procs[i].at <= time &&
                i != current &&
                !in_queue[i]) {
                enqueue(&q, i);
                in_queue[i] = 1;
            }
        }

        /* Cek apakah perlu mengganti proses:
         * - tidak ada proses yang sedang jalan, atau
         * - proses sudah selesai, atau
         * - quantum habis.
         */
        if (current == -1 ||
            procs[current].bt_remaining == 0 ||
            quantum_counter == quantum) {

            /* Jika proses sebelumnya masih punya sisa burst, masukkan lagi ke queue */
            if (current != -1 && procs[current].bt_remaining > 0) {
                enqueue(&q, current);
                in_queue[current] = 1;
            }

            /* Ambil proses berikutnya dari queue jika ada */
            if (!is_queue_empty(&q)) {
                current = dequeue(&q);
                in_queue[current] = 0;
                quantum_counter = 0;
            } else {
                current = -1;
            }
        }

        if (current == -1) {
            /* Tidak ada proses ready: lompat ke arrival time berikutnya */
            int next_at = -1;
            for (int i = 0; i < n; i++) {
                if (procs[i].bt_remaining > 0) {
                    if (next_at == -1 || procs[i].at < next_at) {
                        next_at = procs[i].at;
                    }
                }
            }
            if (next_at == -1) break;
            if (next_at > time) {
                time = next_at;
                continue;
            }
        }

        /* Jika terjadi pergantian proses, tutup segmen Gantt sebelumnya */
        if (current != prev) {
            if (prev != -1) {
                strcpy(gantt[*gantt_size].pid, procs[prev].pid);
                gantt[*gantt_size].start = segment_start;
                gantt[*gantt_size].end = time;
                (*gantt_size)++;
            }
            if (current != -1) {
                segment_start = time;
            }
            prev = current;
        }

        if (current != -1) {
            /* Jalankan proses 1 unit waktu */
            if (!procs[current].started) {
                procs[current].rt = time - procs[current].at;
                procs[current].started = 1;
            }
            procs[current].bt_remaining--;
            quantum_counter++;

            if (procs[current].bt_remaining == 0) {
                /* Proses selesai pada time + 1 */
                procs[current].ct = time + 1;
                procs[current].tat = procs[current].ct - procs[current].at;
                procs[current].wt = procs[current].tat - procs[current].bt;
                completed++;
            }

            time++;
        } else {
            /* Harusnya jarang terjadi karena kita lompat ke next_at di atas */
            time++;
        }
    }

    if (prev != -1) {
        strcpy(gantt[*gantt_size].pid, procs[prev].pid);
        gantt[*gantt_size].start = segment_start;
        gantt[*gantt_size].end = time;
        (*gantt_size)++;
    }
}

/* Mencetak laporan lengkap:
 * - Nama algoritma
 * - Gantt chart
 * - Tabel proses (AT, BT, PR, WT, TAT, RT)
 * - Rata-rata WT, TAT, RT
 */
void print_report(FILE *out,
                  Process procs[], int n,
                  GanttEntry gantt[], int gantt_size,
                  const char *algo_name) {
    double totalWT = 0.0, totalTAT = 0.0, totalRT = 0.0;

    fprintf(out, "Algoritma: %s\n\n", algo_name);

    fprintf(out, "[Gantt Chart]\n");
    for (int i = 0; i < gantt_size; i++) {
        fprintf(out, "| %s ", gantt[i].pid);
    }
    fprintf(out, "|\n\n");

    fprintf(out, "[Tabel]\n");
    fprintf(out, "PID\tAT\tBT\tPR\tWT\tTAT\tRT\n");
    for (int i = 0; i < n; i++) {
        fprintf(out, "%s\t%d\t%d\t%d\t%d\t%d\t%d\n",
                procs[i].pid,
                procs[i].at,
                procs[i].bt,
                procs[i].priority,
                procs[i].wt,
                procs[i].tat,
                procs[i].rt);
        totalWT  += procs[i].wt;
        totalTAT += procs[i].tat;
        totalRT  += procs[i].rt;
    }

    fprintf(out, "\nAverage WT = %.2f\n", totalWT / n);
    fprintf(out, "Average TAT = %.2f\n", totalTAT / n);
    fprintf(out, "Average RT = %.2f\n", totalRT / n);
}

int main(void) {
    Process procs[MAX_PROCESSES];
    GanttEntry gantt[MAX_GANTT_ENTRIES];
    int gantt_size = 0;
    int n;

    printf("==== CPU Scheduling Simulator ====\n");

    /* Pilih sumber input proses */
    int input_choice;
    printf("Pilih input:\n");
    printf("1. Manual\n");
    printf("2. File\n");
    printf("Pilihan: ");
    if (scanf("%d", &input_choice) != 1) {
        printf("Input tidak valid.\n");
        return 1;
    }

    if (input_choice == 1) {
        n = read_processes_manual(procs);
    } else if (input_choice == 2) {
        char filename[256];
        printf("Masukkan nama file: ");
        if (scanf("%255s", filename) != 1) {
            printf("Nama file tidak valid.\n");
            return 1;
        }
        n = read_processes_file(filename, procs);
    } else {
        printf("Pilihan input tidak valid.\n");
        return 1;
    }

    if (n <= 0) {
        return 1;
    }

    /* Pilih algoritma penjadwalan */
    int algo_choice;
    printf("\nPilih algoritma:\n");
    printf("1. FCFS\n");
    printf("2. SJF (Non-preemptive)\n");
    printf("3. Priority (Preemptive)\n");
    printf("4. Round Robin\n");
    printf("Pilihan: ");
    if (scanf("%d", &algo_choice) != 1) {
        printf("Input tidak valid.\n");
        return 1;
    }

    int quantum = 0;
    const char *algo_name = "";

    if (algo_choice == 4) {
        printf("Quantum: ");
        if (scanf("%d", &quantum) != 1 || quantum <= 0) {
            printf("Quantum harus > 0.\n");
            return 1;
        }
    }

    /* Inisialisasi field runtime setiap proses sebelum simulasi */
    for (int i = 0; i < n; i++) {
        procs[i].bt_remaining = procs[i].bt;
        procs[i].ct = 0;
        procs[i].tat = 0;
        procs[i].wt = 0;
        procs[i].rt = 0;
        procs[i].started = 0;
    }

    /* Jalankan algoritma terpilih */
    switch (algo_choice) {
        case 1:
            algo_name = "FCFS";
            schedule_fcfs(procs, n, gantt, &gantt_size);
            break;
        case 2:
            algo_name = "SJF (Non-preemptive)";
            schedule_sjf(procs, n, gantt, &gantt_size);
            break;
        case 3:
            algo_name = "Priority (Preemptive)";
            schedule_priority_preemptive(procs, n, gantt, &gantt_size);
            break;
        case 4:
            algo_name = "Round Robin";
            schedule_round_robin(procs, n, quantum, gantt, &gantt_size);
            break;
        default:
            printf("Pilihan algoritma tidak valid.\n");
            return 1;
    }

    /* Pilihan output: bisa file dulu lalu layar, dsb. */
    int output_choice;
    while (1) {
        printf("\nPilih output:\n");
        printf("1. File\n");
        printf("2. Layar\n");
        printf("Pilihan: ");
        if (scanf("%d", &output_choice) != 1) {
            printf("Input tidak valid.\n");
            return 1;
        }

        if (output_choice == 1) {
            char outname[256];
            printf("Masukkan Nama File: ");
            if (scanf("%255s", outname) != 1) {
                printf("Nama file tidak valid.\n");
                continue;
            }
            FILE *f = fopen(outname, "w");
            if (!f) {
                printf("Tidak bisa membuat file '%s'.\n", outname);
            } else {
                print_report(f, procs, n, gantt, gantt_size, algo_name);
                fclose(f);
                printf("%s selesai dibuat\n", outname);
            }
        } else if (output_choice == 2) {
            print_report(stdout, procs, n, gantt, gantt_size, algo_name);
            break;
        } else {
            printf("Pilihan output tidak valid.\n");
        }
    }

    return 0;
}

/*
 * CONTOH TEST CASE + PENJELASAN (untuk laporan)
 *
 * Misal kita pilih algoritma Round Robin dengan quantum = 2,
 * dan 4 proses berikut:
 *
 *   Jumlah proses: 4
 *   P1  0  5  2
 *   P2  1  3  1
 *   P3  2  8  3
 *   P4  3  6  2
 *
 * Penjelasan singkat perilaku Round Robin pada test case ini:
 *
 * - Semua proses masuk ready queue ketika sudah tiba (arrival time),
 *   kemudian dieksekusi bergiliran dengan jatah waktu (quantum) = 2.
 *
 * - Urutan eksekusi per segmen (Gantt Chart dalam satuan waktu):
 *     [0,2)  : P1  (P1 jalan 2 unit, sisa 3)
 *     [2,4)  : P2  (P2 jalan 2 unit, sisa 1)
 *     [4,6)  : P3  (P3 jalan 2 unit, sisa 6)
 *     [6,8)  : P1  (P1 jalan 2 unit, sisa 1)
 *     [8,10) : P4  (P4 jalan 2 unit, sisa 4)
 *     [10,11): P2  (P2 sisa 1 unit -> selesai di waktu 11)
 *     [11,13): P3  (sisa 4)
 *     [13,14): P1  (sisa 0 -> selesai di waktu 14)
 *     [14,16): P4  (sisa 2)
 *     [16,18): P3  (sisa 2)
 *     [18,20): P4  (sisa 0 -> selesai di waktu 20)
 *     [20,22): P3  (sisa 0 -> selesai di waktu 22)
 *
 * Dari urutan tersebut:
 * - Completion Time (CT):
 *     P1: 14,  P2: 11,  P3: 22,  P4: 20
 * - Turnaround Time (TAT = CT - AT):
 *     P1: 14 - 0  = 14
 *     P2: 11 - 1  = 10
 *     P3: 22 - 2  = 20
 *     P4: 20 - 3  = 17
 * - Waiting Time (WT = TAT - BT):
 *     P1: 14 - 5  = 9
 *     P2: 10 - 3  = 7
 *     P3: 20 - 8  = 12
 *     P4: 17 - 6  = 11
 * - Response Time (RT = waktu pertama kali jalan - AT):
 *     P1: mulai di 0,  RT = 0 - 0 = 0
 *     P2: mulai di 2,  RT = 2 - 1 = 1
 *     P3: mulai di 4,  RT = 4 - 2 = 2
 *     P4: mulai di 8,  RT = 8 - 3 = 5
 *
 * Rata-rata:
 *   Average WT  = (9 + 7 + 12 + 11) / 4 = 9.75
 *   Average TAT = (14 + 10 + 20 + 17) / 4 = 15.25
 *   Average RT  = (0 + 1 + 2 + 5) / 4  = 2.00
 *
 * Angka-angka di atas konsisten dengan definisi WT, TAT, dan RT
 * yang digunakan dalam kode simulator ini.
 */
