import {
  compileScript as sfcCompileScript,
  SFCDescriptor,
  parse as parseToSFCParseResult,
} from "vue/compiler-sfc";
export type ScriptCompilerResult = {
  type: "result" | "error";
  code?: string;
  warnings?: string[];
  error?: string;
};

export function parseToSFCDescriptor(
  sfc: string,
  filename: string
): SFCDescriptor {
  return parseToSFCParseResult(sfc, { filename, ignoreEmpty: true }).descriptor;
}
export function compileScript(
  descriptor: SFCDescriptor,
  filename: string
): ScriptCompilerResult {
  const warnings: string[] = [];
  const origWarn = console.warn;
  console.warn = (...args: any[]) => {
    const raw = args
      .map((a) => (typeof a === "string" ? a : String(a)))
      .join(" ");
    if (raw.includes("[@vue/compiler-sfc]")) {
      const cleaned = raw.replace(/\x1B\[[0-9;]*m/g, "").trim();
      warnings.push(cleaned);
    }
    return origWarn.apply(console, args as any);
  };
  try {
    const script = sfcCompileScript(descriptor, {
      id: filename,
      hoistStatic: false,
    });
    const code = script.content.trim();
    return { type: "result", code };
  } catch (e: any) {
    const errMsg = e?.message ? String(e.message).trim() : String(e);
    return { type: "error", warnings, error: errMsg };
  } finally {
  }
}
