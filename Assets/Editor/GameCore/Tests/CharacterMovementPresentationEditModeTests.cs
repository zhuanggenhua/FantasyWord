using System;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore.Tests
{
    public sealed class CharacterMovementPresentationEditModeTests
    {
        private const string CharacterActorPrefabPath =
            "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab";

        private GameObject m_prefabRoot;

        [TearDown]
        public void TearDown()
        {
            if (m_prefabRoot != null)
            {
                PrefabUtility.UnloadPrefabContents(m_prefabRoot);
                m_prefabRoot = null;
            }
        }

        [Test]
        public void FormalCharacter_DirectionalInputUpdatesFacingBeforePhysicsMovement()
        {
            CharacterActor actor = LoadCharacterActor();
            CharacterMovement movement = actor.GetComponent<CharacterMovement>();

            Assert.That(movement, Is.Not.Null, "正式角色 Prefab 缺少方向移动入口。");

            actor.SetLookAtDirection(Vector2.right);
            bool handled = movement.HandleDirectionalMove(Vector2.left);

            Assert.That(handled, Is.True, "方向输入没有被正式移动入口接收。");
            Assert.That(actor.GetLookAtDirection(), Is.EqualTo(Vector2.left),
                "玩家朝向必须在物理移动和碰撞判断前跟随输入意图。");
        }

        [Test]
        public void FormalCharacter_SteeringMovementDoesNotOverrideFacing()
        {
            CharacterActor actor = LoadCharacterActor();

            actor.SetLookAtDirection(Vector2.right);
            actor.SetSteeringMovementDirection(Vector2.left);

            Assert.That(actor.GetLookAtDirection(), Is.EqualTo(Vector2.right),
                "ContextSteering2D 的安全移动方向只能驱动移动，不能顺手覆盖身体朝向。");
        }

        [Test]
        public void FormalCharacter_MovementResultDrivesWalkThenIdle()
        {
            CharacterActor actor = LoadCharacterActor();
            MonoBehaviour animationDriver = FindComponentByTypeName(actor.gameObject, "CharacterActionAnimatorDriver");
            MethodInfo updateMovementAnimation = actor.GetType().GetMethod(
                "UpdateMovementAnimation",
                BindingFlags.Instance | BindingFlags.NonPublic);

            Assert.That(animationDriver, Is.Not.Null, "正式角色 Prefab 缺少动作动画驱动。");
            Assert.That(updateMovementAnimation, Is.Not.Null, "角色移动结果没有正式表现入口。");

            updateMovementAnimation.Invoke(actor, new object[] { Vector2.right });
            Assert.That(ReadStringProperty(animationDriver, "CurrentAnimationKey"), Is.EqualTo("Walk"));

            updateMovementAnimation.Invoke(actor, new object[] { Vector2.zero });
            Assert.That(ReadStringProperty(animationDriver, "CurrentAnimationKey"), Is.EqualTo("Idle"));
        }

        [Test]
        public void FormalCharacter_SouthWestFacingUsesWestLibraryWithoutHorizontalFlip()
        {
            CharacterActor actor = LoadCharacterActor();
            MonoBehaviour directionDriver = FindComponentByTypeName(actor.gameObject, "DirectionalSpriteLibraryDriver");
            MethodInfo enableDirectionDriver = directionDriver?.GetType().GetMethod(
                "OnEnable",
                BindingFlags.Instance | BindingFlags.NonPublic);
            PropertyInfo currentDirection = directionDriver?.GetType().GetProperty("CurrentDirectionIndex");
            SpriteRenderer spriteRenderer = directionDriver != null
                ? directionDriver.GetComponent<SpriteRenderer>()
                : null;

            Assert.That(directionDriver, Is.Not.Null, "正式角色 Prefab 缺少四向精灵库驱动。");
            Assert.That(enableDirectionDriver, Is.Not.Null);
            Assert.That(currentDirection, Is.Not.Null);
            Assert.That(spriteRenderer, Is.Not.Null, "四向精灵库驱动没有绑定到角色主 SpriteRenderer。");

            spriteRenderer.flipX = false;
            enableDirectionDriver.Invoke(directionDriver, null);
            actor.SetLookAtDirection(new Vector2(-1.0f, -1.0f));

            Assert.That((int)currentDirection.GetValue(directionDriver), Is.EqualTo(1), "西南方向没有切到 SW 精灵库。");
            Assert.That(spriteRenderer.flipX, Is.False, "真实四向素材不得再被旧双向策略水平镜像。");
        }

        [Test]
        public void FormalCharacter_MovementDoesNotOverrideActionAndRestoresWalkAfterwards()
        {
            CharacterActor actor = LoadCharacterActor();
            MonoBehaviour animationDriver = FindComponentByTypeName(actor.gameObject, "CharacterActionAnimatorDriver");
            MethodInfo updateMovementAnimation = GetMovementAnimationMethod(actor);
            MethodInfo playAnimation = animationDriver?.GetType().GetMethod("TryPlayAnimation");
            MethodInfo restoreDefaultAnimation = animationDriver?.GetType().GetMethod("TryRestoreDefaultAnimation");

            Assert.That(animationDriver, Is.Not.Null);
            Assert.That(playAnimation, Is.Not.Null);
            Assert.That(restoreDefaultAnimation, Is.Not.Null);

            Assert.That((bool)playAnimation.Invoke(animationDriver, new object[] { "Attack" }), Is.True);
            updateMovementAnimation.Invoke(actor, new object[] { Vector2.right });
            Assert.That(ReadStringProperty(animationDriver, "CurrentAnimationKey"), Is.EqualTo("Attack"));

            Assert.That((bool)restoreDefaultAnimation.Invoke(animationDriver, new object[] { "Attack" }), Is.True);
            Assert.That(ReadStringProperty(animationDriver, "CurrentAnimationKey"), Is.EqualTo("Walk"));
        }

        private CharacterActor LoadCharacterActor()
        {
            m_prefabRoot = PrefabUtility.LoadPrefabContents(CharacterActorPrefabPath);
            CharacterActor actor = m_prefabRoot.GetComponentInChildren<CharacterActor>(true);
            Assert.That(actor, Is.Not.Null, "正式角色 Prefab 缺少 CharacterActor。");
            return actor;
        }

        private static MethodInfo GetMovementAnimationMethod(CharacterActor actor)
        {
            MethodInfo method = actor.GetType().GetMethod(
                "UpdateMovementAnimation",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.That(method, Is.Not.Null, "角色移动结果没有正式表现入口。");
            return method;
        }

        private static MonoBehaviour FindComponentByTypeName(GameObject root, string typeName)
        {
            MonoBehaviour[] behaviours = root.GetComponentsInChildren<MonoBehaviour>(true);
            return Array.Find(behaviours, behaviour => behaviour != null && behaviour.GetType().Name == typeName);
        }

        private static string ReadStringProperty(object target, string propertyName)
        {
            PropertyInfo property = target?.GetType().GetProperty(propertyName);
            Assert.That(property, Is.Not.Null, $"{target?.GetType().Name} 缺少 {propertyName} 属性。");
            return property.GetValue(target) as string;
        }
    }
}
