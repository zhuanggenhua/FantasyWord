using System;

namespace FantasyWord.GameCore
{
    [Serializable]
    public abstract class QuestTaskProgressDataBlock : DataBlock
    {
        public DatabaseEntryReference<QuestTask> task = null;

        public abstract IQuestTaskProgress CreateInstance();
    }

    public interface IQuestTaskProgress
    {
        public QuestTask task { get; }

        public void Initialize(Action<IQuestTaskProgress> completionCallback);
        public void OnProgressTrackingStarted();
        public void OnProgressTrackingStopped();
        public bool IsCompleted();

        public QuestTaskProgressDataBlock CreateDataBlock();
    }

    public abstract class QuestTaskProgress<T> : IQuestTaskProgress, IDataBlockHandler<T> where T : QuestTaskProgressDataBlock, new()
    {
        protected QuestTask m_task = null;
        private Action<QuestTaskProgress<T>> m_completionCallback;

        QuestTask IQuestTaskProgress.task => m_task;

        public QuestTaskProgress(QuestTask task)
        {
            m_task = task;
        }

        public QuestTaskProgress(T block)
        {
            LoadDataBlock(block);
        }

        ~QuestTaskProgress()
        {
            OnProgressTrackingStopped();
        }


        public void Initialize(Action<IQuestTaskProgress> completionCallback)
        {
            m_completionCallback = completionCallback;
            OnProgressTrackingStarted();
            Update();
        }

        public abstract void OnProgressTrackingStarted();
        public abstract void OnProgressTrackingStopped();
        public abstract bool IsCompleted();
        protected virtual void Update() { }

        public void UpdateProgression()
        {
            if (IsCompleted())
            {
                m_completionCallback(this);
                OnProgressTrackingStopped();
            }
        }

        public virtual void LoadDataBlock(T block)
        {
            m_task = GameManager.Database.LoadFromReference(block.task);
        }

        public virtual T CreateDataBlock()
        {
            return new T
            {
                task = GameManager.Database.CreateReference(m_task)
            };
        }

        QuestTaskProgressDataBlock IQuestTaskProgress.CreateDataBlock() => CreateDataBlock();
    }
}
