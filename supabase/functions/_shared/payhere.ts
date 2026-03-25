type PayHereSignatureInput = {
  merchantId: string;
  orderId: string;
  amount: string;
  currency: string;
  merchantSecret: string;
  statusCode?: string;
};

function rotateLeft(value: number, shift: number): number {
  return (value << shift) | (value >>> (32 - shift));
}

function addUnsigned(first: number, second: number): number {
  const firstHigh = first & 0x80000000;
  const secondHigh = second & 0x80000000;
  const firstCarry = first & 0x40000000;
  const secondCarry = second & 0x40000000;
  const result = (first & 0x3fffffff) + (second & 0x3fffffff);

  if (firstCarry & secondCarry) {
    return result ^ 0x80000000 ^ firstHigh ^ secondHigh;
  }

  if (firstCarry | secondCarry) {
    if (result & 0x40000000) {
      return result ^ 0xc0000000 ^ firstHigh ^ secondHigh;
    }

    return result ^ 0x40000000 ^ firstHigh ^ secondHigh;
  }

  return result ^ firstHigh ^ secondHigh;
}

function f(x: number, y: number, z: number): number {
  return (x & y) | (~x & z);
}

function g(x: number, y: number, z: number): number {
  return (x & z) | (y & ~z);
}

function h(x: number, y: number, z: number): number {
  return x ^ y ^ z;
}

function iFn(x: number, y: number, z: number): number {
  return y ^ (x | ~z);
}

function transform(
  fn: (x: number, y: number, z: number) => number,
  a: number,
  b: number,
  c: number,
  d: number,
  value: number,
  shift: number,
  constant: number,
): number {
  return addUnsigned(rotateLeft(addUnsigned(addUnsigned(a, fn(b, c, d)), addUnsigned(value, constant)), shift), b);
}

function convertToWordArray(value: string): number[] {
  const messageLength = value.length;
  const totalWords = (((messageLength + 8) - ((messageLength + 8) % 64)) / 64 + 1) * 16;
  const words = new Array<number>(totalWords - 1);

  let byteCount = 0;
  while (byteCount < messageLength) {
    const wordCount = (byteCount - (byteCount % 4)) / 4;
    const bytePosition = (byteCount % 4) * 8;
    words[wordCount] = words[wordCount] | (value.charCodeAt(byteCount) << bytePosition);
    byteCount += 1;
  }

  const wordCount = (byteCount - (byteCount % 4)) / 4;
  const bytePosition = (byteCount % 4) * 8;
  words[wordCount] = words[wordCount] | (0x80 << bytePosition);
  words[totalWords - 2] = messageLength << 3;
  words[totalWords - 1] = messageLength >>> 29;

  return words;
}

function wordToHex(value: number): string {
  let output = "";
  for (let count = 0; count <= 3; count += 1) {
    const byte = (value >>> (count * 8)) & 255;
    const hex = `0${byte.toString(16)}`;
    output += hex.slice(-2);
  }

  return output;
}

function utf8Encode(value: string): string {
  return unescape(encodeURIComponent(value));
}

export function md5(value: string): string {
  const message = utf8Encode(value);
  const words = convertToWordArray(message);

  let a = 0x67452301;
  let b = 0xefcdab89;
  let c = 0x98badcfe;
  let d = 0x10325476;

  for (let index = 0; index < words.length; index += 16) {
    const originalA = a;
    const originalB = b;
    const originalC = c;
    const originalD = d;

    a = transform(f, a, b, c, d, words[index + 0], 7, 0xd76aa478);
    d = transform(f, d, a, b, c, words[index + 1], 12, 0xe8c7b756);
    c = transform(f, c, d, a, b, words[index + 2], 17, 0x242070db);
    b = transform(f, b, c, d, a, words[index + 3], 22, 0xc1bdceee);
    a = transform(f, a, b, c, d, words[index + 4], 7, 0xf57c0faf);
    d = transform(f, d, a, b, c, words[index + 5], 12, 0x4787c62a);
    c = transform(f, c, d, a, b, words[index + 6], 17, 0xa8304613);
    b = transform(f, b, c, d, a, words[index + 7], 22, 0xfd469501);
    a = transform(f, a, b, c, d, words[index + 8], 7, 0x698098d8);
    d = transform(f, d, a, b, c, words[index + 9], 12, 0x8b44f7af);
    c = transform(f, c, d, a, b, words[index + 10], 17, 0xffff5bb1);
    b = transform(f, b, c, d, a, words[index + 11], 22, 0x895cd7be);
    a = transform(f, a, b, c, d, words[index + 12], 7, 0x6b901122);
    d = transform(f, d, a, b, c, words[index + 13], 12, 0xfd987193);
    c = transform(f, c, d, a, b, words[index + 14], 17, 0xa679438e);
    b = transform(f, b, c, d, a, words[index + 15], 22, 0x49b40821);

    a = transform(g, a, b, c, d, words[index + 1], 5, 0xf61e2562);
    d = transform(g, d, a, b, c, words[index + 6], 9, 0xc040b340);
    c = transform(g, c, d, a, b, words[index + 11], 14, 0x265e5a51);
    b = transform(g, b, c, d, a, words[index + 0], 20, 0xe9b6c7aa);
    a = transform(g, a, b, c, d, words[index + 5], 5, 0xd62f105d);
    d = transform(g, d, a, b, c, words[index + 10], 9, 0x02441453);
    c = transform(g, c, d, a, b, words[index + 15], 14, 0xd8a1e681);
    b = transform(g, b, c, d, a, words[index + 4], 20, 0xe7d3fbc8);
    a = transform(g, a, b, c, d, words[index + 9], 5, 0x21e1cde6);
    d = transform(g, d, a, b, c, words[index + 14], 9, 0xc33707d6);
    c = transform(g, c, d, a, b, words[index + 3], 14, 0xf4d50d87);
    b = transform(g, b, c, d, a, words[index + 8], 20, 0x455a14ed);
    a = transform(g, a, b, c, d, words[index + 13], 5, 0xa9e3e905);
    d = transform(g, d, a, b, c, words[index + 2], 9, 0xfcefa3f8);
    c = transform(g, c, d, a, b, words[index + 7], 14, 0x676f02d9);
    b = transform(g, b, c, d, a, words[index + 12], 20, 0x8d2a4c8a);

    a = transform(h, a, b, c, d, words[index + 5], 4, 0xfffa3942);
    d = transform(h, d, a, b, c, words[index + 8], 11, 0x8771f681);
    c = transform(h, c, d, a, b, words[index + 11], 16, 0x6d9d6122);
    b = transform(h, b, c, d, a, words[index + 14], 23, 0xfde5380c);
    a = transform(h, a, b, c, d, words[index + 1], 4, 0xa4beea44);
    d = transform(h, d, a, b, c, words[index + 4], 11, 0x4bdecfa9);
    c = transform(h, c, d, a, b, words[index + 7], 16, 0xf6bb4b60);
    b = transform(h, b, c, d, a, words[index + 10], 23, 0xbebfbc70);
    a = transform(h, a, b, c, d, words[index + 13], 4, 0x289b7ec6);
    d = transform(h, d, a, b, c, words[index + 0], 11, 0xeaa127fa);
    c = transform(h, c, d, a, b, words[index + 3], 16, 0xd4ef3085);
    b = transform(h, b, c, d, a, words[index + 6], 23, 0x04881d05);
    a = transform(h, a, b, c, d, words[index + 9], 4, 0xd9d4d039);
    d = transform(h, d, a, b, c, words[index + 12], 11, 0xe6db99e5);
    c = transform(h, c, d, a, b, words[index + 15], 16, 0x1fa27cf8);
    b = transform(h, b, c, d, a, words[index + 2], 23, 0xc4ac5665);

    a = transform(iFn, a, b, c, d, words[index + 0], 6, 0xf4292244);
    d = transform(iFn, d, a, b, c, words[index + 7], 10, 0x432aff97);
    c = transform(iFn, c, d, a, b, words[index + 14], 15, 0xab9423a7);
    b = transform(iFn, b, c, d, a, words[index + 5], 21, 0xfc93a039);
    a = transform(iFn, a, b, c, d, words[index + 12], 6, 0x655b59c3);
    d = transform(iFn, d, a, b, c, words[index + 3], 10, 0x8f0ccc92);
    c = transform(iFn, c, d, a, b, words[index + 10], 15, 0xffeff47d);
    b = transform(iFn, b, c, d, a, words[index + 1], 21, 0x85845dd1);
    a = transform(iFn, a, b, c, d, words[index + 8], 6, 0x6fa87e4f);
    d = transform(iFn, d, a, b, c, words[index + 15], 10, 0xfe2ce6e0);
    c = transform(iFn, c, d, a, b, words[index + 6], 15, 0xa3014314);
    b = transform(iFn, b, c, d, a, words[index + 13], 21, 0x4e0811a1);
    a = transform(iFn, a, b, c, d, words[index + 4], 6, 0xf7537e82);
    d = transform(iFn, d, a, b, c, words[index + 11], 10, 0xbd3af235);
    c = transform(iFn, c, d, a, b, words[index + 2], 15, 0x2ad7d2bb);
    b = transform(iFn, b, c, d, a, words[index + 9], 21, 0xeb86d391);

    a = addUnsigned(a, originalA);
    b = addUnsigned(b, originalB);
    c = addUnsigned(c, originalC);
    d = addUnsigned(d, originalD);
  }

  return `${wordToHex(a)}${wordToHex(b)}${wordToHex(c)}${wordToHex(d)}`.toUpperCase();
}

export function formatPayHereAmount(amount: number | string): string {
  const parsed = typeof amount === "string" ? Number(amount) : amount;
  return parsed.toFixed(2);
}

export function buildPayHereSignature(input: PayHereSignatureInput): string {
  const merchantSecretHash = md5(input.merchantSecret);
  const base = input.statusCode
    ? `${input.merchantId}${input.orderId}${input.amount}${input.currency}${input.statusCode}${merchantSecretHash}`
    : `${input.merchantId}${input.orderId}${input.amount}${input.currency}${merchantSecretHash}`;

  return md5(base);
}

export function getPayHereCheckoutUrl(isSandbox: boolean): string {
  return isSandbox ? "https://sandbox.payhere.lk/pay/checkout" : "https://www.payhere.lk/pay/checkout";
}
