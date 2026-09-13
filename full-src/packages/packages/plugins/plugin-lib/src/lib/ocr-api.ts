export interface IOcrService {
  doOcrFromImage(opts: { image: string }): Promise<{ texts: string[] }>;
}
