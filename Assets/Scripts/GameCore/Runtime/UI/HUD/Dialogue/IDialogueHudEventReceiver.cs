namespace FantasyWord.GameCore
{
    /// <summary>
    /// 对话 HUD 内部组件与父级界面之间的正式回调合同。
    /// 只服务 UIDialogue 闭包，用来替代消息框与选项按钮对父级的字符串上行消息。
    /// </summary>
    public interface IDialogueHudEventReceiver
    {
        /// <summary>消息框跳字播放完成后通知父级刷新选项框。</summary>
        void HandleMessageBoxTextAnimationFinished();

        /// <summary>选项按钮点击后通知父级推进对话分支。</summary>
        void HandleDialogueOptionClicked(int option);
    }
}
