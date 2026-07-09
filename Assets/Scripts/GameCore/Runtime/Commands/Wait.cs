using System;
using System.Collections;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class Wait : IContextualCommand
    {
        [SerializeField] private float m_duration = 1.0f;

        // Why is this so complicated? Well, Task.Delay doesn't work with WebGL!
        // Instead, this method uses a coroutine to wait for the specified duration.
        // We could technically branch this method to use Task.Delay on non-WebGL platforms,
        // but I'm keeping it simple for now.
        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            await WaitForSecondsAsync(GameManager.Instance, m_duration);
        }

        private Task WaitForSecondsAsync(MonoBehaviour monoBehaviour, float seconds)
        {
            var tcs = new TaskCompletionSource<bool>();
            monoBehaviour.StartCoroutine(WaitCoroutine(seconds, tcs));
            return tcs.Task;
        }

        private IEnumerator WaitCoroutine(float seconds, TaskCompletionSource<bool> tcs)
        {
            yield return new WaitForSeconds(seconds);
            tcs.SetResult(true);
        }
    }
}

