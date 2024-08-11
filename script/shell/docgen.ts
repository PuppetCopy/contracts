import { $, Glob, write, file } from "bun";

await $`forge doc --out "docs/generated" --build`;

const files = new Glob("docs/generated/**/*");

for await (const match of files.scan(".")) {
    if (/^(?!.*(\/interface\/|\/utils\/)).*\.md$/.test(match)) {        
        const matchLoc = match.replace("docs/generated/src", "")

        // await Bun.write(Bun.stdout, `${matchLoc}\n`);
        await write(file(`docs/contracts/pages/${matchLoc}`), file(match), { createPath: true });
    }
}

await $`rm -rf docs/generated`;

