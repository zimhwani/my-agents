// Runs under vitest (npm test), not Deno: only pure helpers are imported.
import { describe, expect, it } from "vitest";
import { authCodeMessage } from "./whatsapp.ts";

describe("WhatsApp sign-in code", () => {
  it("fills the Authentication template's body and copy-code button with the code", () => {
    expect(authCodeMessage("263771234567", "482913", "gasguys_login_code")).toEqual({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: "263771234567",
      type: "template",
      template: {
        name: "gasguys_login_code",
        language: { code: "en" },
        components: [
          { type: "body", parameters: [{ type: "text", text: "482913" }] },
          { type: "button", sub_type: "url", index: "0", parameters: [{ type: "text", text: "482913" }] },
        ],
      },
    });
  });
});
