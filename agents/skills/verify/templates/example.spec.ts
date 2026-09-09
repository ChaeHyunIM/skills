import { expect, test } from "@playwright/test";

// 완료 조건 하나 = test 하나. 제목은 조건 원문 그대로 쓴다.
// 조작 전·조작·결과 스크린샷은 spec 이 직접 찍는다 — 영상에서 프레임을 뽑는 것보다 결정적이다.
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

// 상태 조건은 assertion 하나와 스크린샷 하나면 된다.
test("상세 화면 상단에 만료일이 표시된다", async ({ page }, info) => {
  await page.goto("/gift-cards/7");
  await expect(page.getByTestId("expires-at")).toBeVisible();
  await page.screenshot({ path: info.outputPath("state.png") });
});
