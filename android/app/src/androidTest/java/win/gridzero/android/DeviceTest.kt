package win.gridzero.android

import android.Manifest
import android.content.pm.PackageManager
import android.content.pm.ActivityInfo
import android.graphics.Rect
import android.view.View
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import win.gridzero.android.core.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class DeviceTest {
    private fun prepare(scenario: ActivityScenario<MainActivity>, mode: PlayMode) {
        val ready = CountDownLatch(1)
        scenario.onActivity { a -> a.startPuzzle(Difficulty.EASY, mode, PuzzleSource.COLLECTION, 45) { error -> assertNull(error); ready.countDown() } }
        assertTrue(ready.await(20, TimeUnit.SECONDS))
        Thread.sleep(250)
    }
    @Test fun realDeviceLayoutNotesStrikesAndPersistence() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            val ready = CountDownLatch(1)
            scenario.onActivity { activity ->
                activity.startPuzzle(Difficulty.EASY, PlayMode.CHALLENGE, PuzzleSource.COLLECTION, 45) { error ->
                    assertNull(error); ready.countDown()
                }
            }
            assertTrue(ready.await(20, TimeUnit.SECONDS))
            Thread.sleep(350)
            scenario.onActivity { a ->
                val surface = a.surface
                assertTrue(surface.menu.isShown)
                assertEquals("•••", surface.menu.text.toString())
                assertTrue("Menu bounds: ${surface.menu.left}, ${surface.menu.top}, ${surface.menu.width}, ${surface.menu.height}", surface.menu.width >= a.dp(48f) - 1)
                val safe = Rect(surface.paddingLeft, surface.paddingTop, surface.width - surface.paddingRight, surface.height - surface.paddingBottom)
                assertEquals(surface.width - surface.paddingLeft - surface.paddingRight, surface.board.width)
                for (button in surface.numberButtons.values) {
                    assertTrue(safe.contains(button.left, button.top, button.right, button.bottom))
                    assertTrue(button.width >= a.dp(48f) - 1 && button.height >= a.dp(48f) - 1)
                }
                val one = surface.numberButtons.getValue(1); val two = surface.numberButtons.getValue(2); val three = surface.numberButtons.getValue(3)
                assertTrue(two.top > one.top && two.x > one.x && two.x < three.x)
                val index = a.game!!.board.values.indexOfFirst { it == 0 }
                a.selected = index
                a.findViewById<View>(R.id.notes).performClick()
                surface.numberButtons.getValue(2).performClick()
                assertEquals(1 shl 2, a.game!!.board.notes[index])
                a.findViewById<View>(R.id.undo).performClick(); assertEquals(0, a.game!!.board.notes[index])
                a.findViewById<View>(R.id.notes).performClick()
                val correct = a.game!!.puzzle.solution[index]
                surface.numberButtons.getValue(correct % 9 + 1).performClick()
                assertEquals(1, a.game!!.strikes); assertEquals(0, a.game!!.board.values[index])
            }
            Thread.sleep(650)
            var index = -1; var correct = -1
            scenario.onActivity { a ->
                index = a.selected; correct = a.game!!.puzzle.solution[index]
                assertEquals(index, a.errorCell)
                a.surface.numberButtons.getValue(correct).performClick()
            }
            Thread.sleep(350)
            scenario.onActivity { a -> assertEquals(correct, a.game!!.board.values[index]); a.save() }
            Thread.sleep(350)
            scenario.recreate()
            scenario.onActivity { a ->
                assertEquals(correct, a.game!!.board.values[index]); assertEquals(1, a.game!!.strikes)
                assertEquals(PackageManager.PERMISSION_DENIED, a.checkSelfPermission(Manifest.permission.INTERNET))
                assertFalse(a.packageManager.getPackageInfo(a.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions.orEmpty().contains(Manifest.permission.INTERNET))
            }
        }
    }
    @Test fun appearanceAndCandidateAssistanceAreOptIn() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { a ->
                a.settings.appearance = Appearance.DARK; a.settings.theme = Theme.MOSS
                a.settings.save(a); a.refresh(); assertTrue(a.palette.dark)
                a.settings.appearance = Appearance.SCHEDULED; a.settings.lightAt = 420; a.settings.darkAt = 1140
                assertFalse(a.settings.isDark(a.resources.configuration, 600))
                assertTrue(a.settings.isDark(a.resources.configuration, 1200))
                a.settings.appearance = Appearance.SYSTEM; a.settings.theme = Theme.INK; a.settings.save(a); a.refresh()
            }
        }
    }
    @Test fun classicAndLandscapeRemainPlayable() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            prepare(scenario, PlayMode.CLASSIC)
            var index = -1; var wrong = -1
            scenario.onActivity { a ->
                index = a.game!!.board.values.indexOfFirst { it == 0 }; a.selected = index
                wrong = a.game!!.puzzle.solution[index] % 9 + 1
                a.surface.numberButtons.getValue(wrong).performClick()
            }
            Thread.sleep(300)
            scenario.onActivity { a ->
                assertEquals(wrong, a.game!!.board.values[index]); assertEquals(0, a.game!!.strikes)
                a.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            Thread.sleep(750)
            scenario.onActivity { a ->
                assertTrue(a.surface.layoutSpec!!.sideBySide)
                assertEquals(a.surface.board.width, a.surface.board.height)
                val safe = Rect(a.surface.paddingLeft, a.surface.paddingTop,
                    a.surface.width - a.surface.paddingRight, a.surface.height - a.surface.paddingBottom)
                for (key in a.surface.numberButtons.values) assertTrue(safe.contains(key.left, key.top, key.right, key.bottom))
                assertEquals(wrong, a.game!!.board.values[index])
                a.game!!.undo(); a.changed(); assertEquals(0, a.game!!.board.values[index])
                a.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
    }
}
