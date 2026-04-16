package tool;

import firrtl.ir.Circuit;

public final class FirrtlCompat {
  private FirrtlCompat() {}

  public static Circuit parseCircuit(String text) {
    try {
      Class<?> parserClass = Class.forName("firrtl.Parser$");
      Object module = parserClass.getField("MODULE$").get(null);
      return (Circuit) parserClass.getMethod("parse", String.class).invoke(module, text);
    } catch (ReflectiveOperationException e) {
      throw new RuntimeException("Failed to invoke FIRRTL parser", e);
    }
  }
}
