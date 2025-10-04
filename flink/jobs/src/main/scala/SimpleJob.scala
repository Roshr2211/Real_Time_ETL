package jobs

import org.apache.flink.streaming.api.scala._

object SimpleJob {
  def main(args: Array[String]): Unit = {
    val env = StreamExecutionEnvironment.getExecutionEnvironment
    val text = env.fromElements("hello", "world")
    text.print()
    env.execute("Simple Flink Job")
  }
}
