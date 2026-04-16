package tool

import firrtl.ir.Circuit

object FirrtlCompat {
  def parseCircuit(text: String): Circuit = {
    try {
      val parserClass = Class.forName("firrtl.Parser$")
      val module = parserClass.getField("MODULE$").get(null)
      parserClass.getMethod("parse", classOf[String]).invoke(module, text).asInstanceOf[Circuit]
    } catch {
      case e: ReflectiveOperationException =>
        throw new RuntimeException("Failed to invoke FIRRTL parser", e)
    }
  }
}
