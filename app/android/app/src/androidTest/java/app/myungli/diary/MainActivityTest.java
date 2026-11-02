package app.myungli.diary;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.SystemClock;
import android.util.Log;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.runner.lifecycle.ActivityLifecycleMonitor;
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry;
import androidx.test.runner.lifecycle.Stage;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.After;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

@RunWith(Parameterized.class)
public class MainActivityTest {
    private static final String TAG = "MainActivityTest";

    /** 테스트 뒤 Activity가 닫히기를 기다리는 최대 시간. 넘겨도 테스트 결과는 바꾸지 않습니다. */
    private static final long CLOSE_TIMEOUT_MS = 10000;

    private static final EnumSet<Stage> LIVE_STAGES = EnumSet.of(
            Stage.PRE_ON_CREATE, Stage.CREATED, Stage.STARTED, Stage.RESUMED,
            Stage.PAUSED, Stage.STOPPED, Stage.RESTARTED);

    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }

    /**
     * 테스트가 끝나면 앱 Activity를 직접 닫고, 닫힐 때까지 기다린 뒤 instrumentation을 끝냅니다.
     *
     * <p>Patrol은 앱을 띄우기만 하고 닫지 않습니다. Activity가 살아 있는 채로 instrumentation이 끝나면
     * API 34 에뮬레이터는 task 제거를 destroy timeout(약 1.4초 뒤)으로 미루고, 그 시점에 같은 이름의
     * 앱 프로세스를 죽입니다. Orchestrator가 그 사이에 다음 테스트 프로세스를 띄우면 그 프로세스가
     * 죽어 "Test instrumentation process crashed"가 되고, Patrol 요약에서는 빠진 채 Gradle만
     * 실패합니다(#700).
     */
    @After
    public void closeAppUnderTest() throws InterruptedException {
        Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
        instrumentation.runOnMainSync(() -> {
            for (Activity activity : liveActivities()) {
                activity.finishAndRemoveTask();
            }
        });

        long deadline = SystemClock.uptimeMillis() + CLOSE_TIMEOUT_MS;
        AtomicBoolean closed = new AtomicBoolean(false);
        while (SystemClock.uptimeMillis() < deadline) {
            instrumentation.runOnMainSync(() -> closed.set(liveActivities().isEmpty()));
            if (closed.get()) {
                return;
            }
            Thread.sleep(50);
        }
        Log.w(TAG, "Activity가 " + CLOSE_TIMEOUT_MS + "ms 안에 닫히지 않았습니다: " + dartTestName);
    }

    /** 아직 destroy되지 않은 Activity. main thread에서만 부릅니다. */
    private static List<Activity> liveActivities() {
        ActivityLifecycleMonitor monitor = ActivityLifecycleMonitorRegistry.getInstance();
        List<Activity> activities = new ArrayList<>();
        for (Stage stage : LIVE_STAGES) {
            activities.addAll(monitor.getActivitiesInStage(stage));
        }
        return activities;
    }
}
