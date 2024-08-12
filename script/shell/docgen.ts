import { $, Glob, write, file } from "bun";

await $`rm -rf docs/pages/contracts`;
await $`forge doc --out "docs/generated" --build`;

const files = new Glob("docs/generated/**/*.md");

await write(file(`docs/pages/contracts/README.md`), file('docs/generated/src/README.md'), { createPath: true });
await write(file(`docs/pages/contracts/README/LICENSE.md`), file('LICENSE'), { createPath: true });

for await (const match of files.scan(".")) {
    if (/(.*)\/([^\/]+)\.sol\/[^\/]+\.md$/.test(match)) {
        const matchLoc = match.replace("docs/generated/src/src", "").replace(/(.*)\/([^\/]+)\.sol\/[^\/]+\.md$/, "$1/$2.md")
        const filename = `docs/pages/contracts/${matchLoc}`

        await Bun.write(Bun.stdout, `${filename}\n`);
        await write(file(filename), file(match), { createPath: true });
    }
}

await $`rm -rf docs/generated`;

