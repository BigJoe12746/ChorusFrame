// Word-level transcription.
//
// Alignment needs to know roughly when each word is sung. That's the one part
// of the pipeline that needs a model, so it sits behind a small interface:
// configure a provider and lyric timing becomes real; configure nothing and
// the aligner falls back to syllable-weighted estimates.
//
// Providers are chosen by which key is present in the environment.

/**
 * @returns {{name: string, transcribe: (url: string) => Promise<{words: Array<{word:string,start:number,end:number}>}>} | null}
 */
export function getTranscriber(env) {
  if (env.OPENAI_API_KEY) return openAiWhisper(env.OPENAI_API_KEY);
  if (env.DEEPGRAM_API_KEY) return deepgram(env.DEEPGRAM_API_KEY);
  return null;
}

/** OpenAI Whisper — verbose_json with word granularity gives per-word times. */
function openAiWhisper(apiKey) {
  return {
    name: "whisper",
    async transcribe(audioUrl) {
      const audio = await fetch(audioUrl);
      if (!audio.ok) throw new Error(`fetching audio failed: ${audio.status}`);
      const blob = await audio.blob();

      const form = new FormData();
      // Extension matters to the API's format sniffing; the URL is signed and
      // ends in the real filename, so reuse it when we can.
      const name = new URL(audioUrl).pathname.split("/").pop() || "audio.wav";
      form.append("file", blob, name);
      form.append("model", "whisper-1");
      form.append("response_format", "verbose_json");
      form.append("timestamp_granularities[]", "word");

      const res = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}` },
        body: form,
      });
      if (!res.ok) {
        throw new Error(`transcription failed (${res.status}): ${(await res.text()).slice(0, 200)}`);
      }
      const data = await res.json();
      const words = (data.words ?? []).map((w) => ({
        word: w.word,
        start: Number(w.start),
        end: Number(w.end),
      }));
      return { words };
    },
  };
}

/** Deepgram — nova with utterances also returns word timings. */
function deepgram(apiKey) {
  return {
    name: "deepgram",
    async transcribe(audioUrl) {
      const res = await fetch(
        "https://api.deepgram.com/v1/listen?model=nova-2&punctuate=true&detect_language=true",
        {
          method: "POST",
          headers: { Authorization: `Token ${apiKey}`, "Content-Type": "application/json" },
          body: JSON.stringify({ url: audioUrl }),
        }
      );
      if (!res.ok) {
        throw new Error(`transcription failed (${res.status}): ${(await res.text()).slice(0, 200)}`);
      }
      const data = await res.json();
      const words = (data?.results?.channels?.[0]?.alternatives?.[0]?.words ?? []).map((w) => ({
        word: w.punctuated_word ?? w.word,
        start: Number(w.start),
        end: Number(w.end),
      }));
      return { words };
    },
  };
}
