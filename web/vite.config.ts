import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from 'vite-plugin-pwa';
import fs from "node:fs";
import path from "path";

const sharedDeps = [
  "react",
  "react-dom",
  "react-dom/client",
  "react/jsx-runtime",
  "react/jsx-dev-runtime",
  "react-router",
  "react-router/dom",
  "react-router-dom",
  "framer-motion",
  "sonner",
  "@tanstack/react-query",
];

const packageJsonCache = new Map<string, any>();

function parsePackageSpecifier(source: string) {
  if (
    source.startsWith(".") ||
    source.startsWith("/") ||
    source.startsWith("\0") ||
    source.startsWith("@/") ||
    /^[A-Za-z]:[\\/]/.test(source)
  ) {
    return null;
  }

  if (source.startsWith("@")) {
    const parts = source.split("/");
    if (parts.length < 2) {
      return null;
    }

    return {
      packageName: `${parts[0]}/${parts[1]}`,
      subpath: parts.length > 2 ? `./${parts.slice(2).join("/")}` : ".",
    };
  }

  const parts = source.split("/");

  return {
    packageName: parts[0],
    subpath: parts.length > 1 ? `./${parts.slice(1).join("/")}` : ".",
  };
}

function getPackageJson(packageRoot: string) {
  const packageJsonPath = path.join(packageRoot, "package.json");
  if (!fs.existsSync(packageJsonPath)) {
    return null;
  }

  if (!packageJsonCache.has(packageJsonPath)) {
    packageJsonCache.set(packageJsonPath, JSON.parse(fs.readFileSync(packageJsonPath, "utf8")));
  }

  return packageJsonCache.get(packageJsonPath);
}

function getExportTarget(exportsEntry: any, condition: "import" | "require") {
  if (!exportsEntry) {
    return null;
  }

  if (typeof exportsEntry === "string") {
    return exportsEntry;
  }

  const conditionalEntry = exportsEntry[condition];
  if (typeof conditionalEntry === "string") {
    return conditionalEntry;
  }

  if (conditionalEntry && typeof conditionalEntry === "object" && typeof conditionalEntry.default === "string") {
    return conditionalEntry.default;
  }

  if (typeof exportsEntry.default === "string") {
    return exportsEntry.default;
  }

  return null;
}

function createMissingEsmFallbackPlugin() {
  return {
    name: "missing-esm-fallback",
    enforce: "pre" as const,
    resolveId(source: string) {
      const specifier = parsePackageSpecifier(source);
      if (!specifier) {
        return null;
      }

      const packageRoot = path.resolve(__dirname, "node_modules", specifier.packageName);
      if (!fs.existsSync(packageRoot)) {
        return null;
      }

      const packageJson = getPackageJson(packageRoot);
      if (!packageJson) {
        return null;
      }

      const exportsEntry = packageJson.exports
        ? specifier.subpath === "."
          ? packageJson.exports["."] ?? packageJson.exports
          : packageJson.exports[specifier.subpath]
        : null;

      const importTarget = getExportTarget(exportsEntry, "import") ?? (specifier.subpath === "." ? packageJson.module : null);
      const requireTarget = getExportTarget(exportsEntry, "require") ?? (specifier.subpath === "." ? packageJson.main : null);

      if (typeof importTarget === "string") {
        const importPath = path.resolve(packageRoot, importTarget);
        if (fs.existsSync(importPath)) {
          return null;
        }
      }

      if (typeof requireTarget === "string") {
        const requirePath = path.resolve(packageRoot, requireTarget);
        if (fs.existsSync(requirePath)) {
          return requirePath;
        }
      }

      return null;
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig(() => {
  const enablePwa = process.env.ENABLE_PWA === "true";

  return {
    server: {
      host: "::",
      port: 8080,
      hmr: {
        overlay: false,
      },
    },
    plugins: [
      createMissingEsmFallbackPlugin(),
      react(),
      enablePwa && VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['favicon.png', 'robots.txt', 'apple-touch-icon.png'],
        manifest: {
          name: 'Pearl Hub | Sri Lanka Luxury Marketplace',
          short_name: 'Pearl Hub',
          description: 'Premium real estate, stays, and tourism in Sri Lanka.',
          theme_color: '#C5A059',
          background_color: '#09090b',
          display: 'standalone',
          icons: [
            {
              src: 'favicon.png',
              sizes: '192x192',
              type: 'image/png'
            },
            {
              src: 'favicon.png',
              sizes: '512x512',
              type: 'image/png'
            },
            {
              src: 'favicon.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'any maskable'
            }
          ]
        }
      })
    ].filter(Boolean),
    resolve: {
      alias: [
        { find: /^react-router\/dom$/, replacement: path.resolve(__dirname, "./node_modules/react-router/dist/development/dom-export.js") },
        { find: /^react-router$/, replacement: path.resolve(__dirname, "./node_modules/react-router/dist/development/index.js") },
        { find: /^framer-motion$/, replacement: path.resolve(__dirname, "./node_modules/framer-motion/dist/cjs/index.js") },
        { find: /^sonner$/, replacement: path.resolve(__dirname, "./node_modules/sonner/dist/index.js") },
        { find: /^@radix-ui\/(react-[^/]+)$/, replacement: path.resolve(__dirname, "./node_modules/@radix-ui/$1/dist/index.js") },
        { find: /^@\//, replacement: `${path.resolve(__dirname, "./src")}/` },
        { find: /^react$/, replacement: path.resolve(__dirname, "./node_modules/react") },
        { find: /^react-dom$/, replacement: path.resolve(__dirname, "./node_modules/react-dom") },
        { find: /^react\/jsx-runtime$/, replacement: path.resolve(__dirname, "./node_modules/react/jsx-runtime.js") },
        { find: /^react\/jsx-dev-runtime$/, replacement: path.resolve(__dirname, "./node_modules/react/jsx-dev-runtime.js") },
      ],
      dedupe: sharedDeps,
    },
    optimizeDeps: {
      include: sharedDeps,
      force: true,
    },
  };
});
