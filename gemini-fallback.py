#!/usr/bin/env python3
"""
Gemini Model Fallback Handler
할당량 초과 시 자동으로 다른 모델로 전환하고 인계 시스템
"""

import subprocess
import json
import sys
import time
from typing import List, Dict, Optional

class GeminiModelFallback:
    """Gemini 모델 자동 전환 시스템"""

    # 모델 우선순위 (Pro → Flash → Preview → Lite)
    MODEL_PRIORITIES = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-preview-09-2025",
        "gemini-2.5-flash-lite",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
    ]

    # 마스터 에이전트 인계 트리거
    MAX_RETRIES_PER_MODEL = 3
    TOTAL_CYCLE_LIMIT = 3  # 전체 사이클 제한

    def __init__(self, master_mode: bool = False):
        """
        초기화

        Args:
            master_mode: True면 마스터 에이전트 모드 (직접 사용자에게 인계)
        """
        self.master_mode = master_mode
        self.current_model_index = 0
        self.retry_count = 0
        self.cycle_count = 0

    def get_available_models(self) -> List[str]:
        """사용 가능한 모델 리스트 반환"""
        return self.MODEL_PRIORITIES.copy()

    def get_current_model(self) -> str:
        """현재 모델 반환"""
        return self.MODEL_PRIORITIES[self.current_model_index]

    def _check_quota_error(self, error_output: str) -> bool:
        """할당량 에러 확인"""
        quota_indicators = [
            "quota",
            "Quota exceeded",
            "limit",
            "429",
            "rate limit"
        ]
        return any(indicator in error_output.lower() for indicator in quota_indicators)

    def _execute_with_model(self, model: str, prompt: str,
                           timeout: int = 60) -> Dict:
        """특정 모델로 명령어 실행"""
        cmd = ["gemini", "--model", model, "-p", prompt]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            return {
                "success": result.returncode == 0,
                "model": model,
                "output": result.stdout,
                "error": result.stderr,
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "model": model,
                "error": f"Timeout after {timeout}s",
                "returncode": -1
            }
        except Exception as e:
            return {
                "success": False,
                "model": model,
                "error": str(e),
                "returncode": -1
            }

    def _fallback_to_next_model(self) -> bool:
        """다음 모델로 전환"""
        if self.current_model_index < len(self.MODEL_PRIORITIES) - 1:
            self.current_model_index += 1
            self.retry_count = 0
            return True
        return False

    def _reset_cycle(self) -> bool:
        """사이클 리셋"""
        self.cycle_count += 1
        if self.cycle_count >= self.TOTAL_CYCLE_LIMIT:
            return False

        self.current_model_index = 0
        self.retry_count = 0
        return True

    def _notify_master(self, last_error: str) -> str:
        """마스터 에이전트(Claude)에게 인계"""
        import datetime

        current_hour = datetime.datetime.now().hour
        hours_until_reset = 24 - current_hour

        message = f"""
╔══════════════════════════════════════════════════════════╗
║  🔴 GEMINI MODEL FALLBACK - MASTER AGENT NOTIFICATION           ║
╚══════════════════════════════════════════════════════════╝

All Gemini models have been exhausted after {self.cycle_count} cycle(s).

Current Status:
  - Last attempted model: {self.get_current_model()}
  - Total models tried: {len(self.MODEL_PRIORITIES)}
  - Retry attempts per model: {self.MAX_RETRIES_PER_MODEL}
  - Last error: {last_error[:150]...}

Recommendations:
  1. Check API key quota at https://aistudio.google.com/app/apikey
  2. Wait for quota reset (daily at midnight Pacific Time)
  3. Upgrade to paid plan for higher limits
  4. Consider using Claude directly (which you're using now!)

Time until reset: Approximately {hours_until_reset} hours

Fallback system terminating. Master agent (Claude) should handle this task.
"""
        return message

    def execute(self, prompt: str, timeout: int = 60,
                verbose: bool = True) -> Dict:
        """
        명령어 실행 (자동 장애 복구 포함)

        Args:
            prompt: 실행할 프롬프트
            timeout: 타임아웃 (초)
            verbose: 진행 상황 출력

        Returns:
            결과 딕셔너리
        """
        while True:
            current_model = self.get_current_model()

            if verbose:
                print(f"🤖 Attempting model: {current_model}")
                print(f"   Cycle {self.cycle_count + 1}/{self.TOTAL_CYCLE_LIMIT}")
                print(f"   Retry {self.retry_count + 1}/{self.MAX_RETRIES_PER_MODEL}")
                print(f"   Model index: {self.current_model_index + 1}/{len(self.MODEL_PRIORITIES)}")

            result = self._execute_with_model(current_model, prompt, timeout)

            # 성공
            if result["success"]:
                if verbose:
                    print(f"✅ Success with model: {current_model}")

                # 상태 리셋
                self.cycle_count = 0
                self.current_model_index = 0
                self.retry_count = 0

                return {
                    **result,
                    "fallback_used": self.cycle_count > 0 or self.current_model_index > 0,
                    "cycles": self.cycle_count
                }

            # 실패 분석
            if self._check_quota_error(result.get("error", "")):
                # 할당량 에러 - 재시도 또는 다음 모델
                if verbose:
                    print(f"⚠️  Quota error with {current_model}")

                self.retry_count += 1

                if self.retry_count >= self.MAX_RETRIES_PER_MODEL:
                    # 현재 모델 재시도 횟수 정하면 다음 모델로
                    if verbose:
                        print(f"🔄 Max retries reached for {current_model}")

                    if not self._fallback_to_next_model():
                        # 모든 모델 시도 실패
                        if not self._reset_cycle():
                            # 사이클 리밋도 실패하면 마스터 인계
                            error_msg = self._notify_master(result["error"])
                            print(error_msg)

                            if self.master_mode:
                                # 대화형 인계
                                user_input = input("\nPress Enter to exit or type 'retry' to start over: ")
                                if user_input.lower() == 'retry':
                                    self.__init__(master_mode=True)
                                    continue

                            return {
                                "success": False,
                                "error": "All models exhausted. Master handoff required.",
                                "models_attempted": self.MODEL_PRIORITIES,
                                "last_error": result["error"]
                            }
                    else:
                        if verbose:
                            print(f"🔄 Cycling back to first model (cycle {self.cycle_count + 1})")
                        time.sleep(2)  # 잠시 후 재시도
                        continue
                else:
                    if verbose:
                        print(f"⏳ Retrying {current_model} in 5 seconds...")
                    time.sleep(5)
                    continue
            else:
                # 다른 에러 - 바로 인계
                error_msg = self._notify_master(result["error"])
                print(error_msg)

                return {
                    "success": False,
                    "error": f"Non-quota error with {current_model}: {result['error']}",
                    "models_attempted": self.get_available_models()
                }


# CLI 인터페이스
def main():
    """CLI 엔트리 포인트"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Gemini Model Fallback Handler"
    )

    parser.add_argument(
        "prompt",
        help="Prompt to send to Gemini"
    )

    parser.add_argument(
        "-m", "--mode",
        choices=["auto", "master"],
        default="auto",
        help="Operation mode: auto (with fallback) or master (notify on failure)"
    )

    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output"
    )

    args = parser.parse_args()

    # Fallback 핸들러 초기화
    handler = GeminiModelFallback(master_mode=(args.mode == "master"))

    # 실행
    result = handler.execute(args.prompt, verbose=args.verbose)

    # 결과 출력
    if result["success"]:
        print("\n" + "="*60)
        print("✅ SUCCESS")
        print("="*60)
        print(result["output"])
    else:
        print("\n" + "="*60)
        print("❌ FAILED")
        print("="*60)
        print(f"Error: {result.get('error', 'Unknown error')}")
        sys.exit(1)


if __name__ == "__main__":
    main()
