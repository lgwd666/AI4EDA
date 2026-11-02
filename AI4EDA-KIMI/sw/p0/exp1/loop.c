/* P0a 实验1：累加 1..10，结果存全局变量 sum
 * 观察目标：循环在机器层面是什么样子
 */
int sum = 0;

int main() {
    for (int i = 1; i <= 10; i++) {
        sum += i;
    }
    return sum;   /* 期望 55 */
}
