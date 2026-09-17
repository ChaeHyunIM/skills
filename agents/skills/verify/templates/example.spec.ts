import { expect, test } from "@playwright/test";

// 흐름 검증은 E2E_VIDEO=1로 실행하고, 캡처와 영상은 완료 조건에 연결한다.
test("이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다", async ({ page }, info) => {
  info.annotations.push({ type: "claim", description: "YOU-123 완료 조건 2" });

  await page.goto("/missions/42");
  await expect(page.getByRole("button", { name: "참여하기" })).toBeVisible();
  await page.screenshot({ path: info.outputPath("before-action.png") });

  await page.getByRole("button", { name: "참여하기" }).click();
  await page.screenshot({ path: info.outputPath("action.png") });

  // 타임아웃은 통과 기준(PASS when …)에 적은 값과 같아야 한다.
  await expect(page.getByText("이미 참여 중")).toBeVisible({ timeout: 3_000 });
  await page.screenshot({ path: info.outputPath("result.png") });
});

// 상태 캡처 예시. 기존 화면 변경은 같은 조건으로 base/head에서 실행한다.
test("상세 화면 상단에 만료일이 표시된다", async ({ page }, info) => {
  await page.goto("/gift-cards/7");
  await expect(page.getByTestId("expires-at")).toBeVisible();
  await page.screenshot({ path: info.outputPath("state.png") });
});
